package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/clientcmd/api"
)

func main() {
	debugMode := os.Getenv("DEBUG") == "1" || os.Getenv("DEBUG") == "true"
	var kubeconfig, kubecontext, namespace, deploymentName, podName, nodeName string
	var clientset *kubernetes.Clientset

	if debugMode {
		fmt.Println("[DEBUG MODE] Running in manual interactive mode.")
		// 1. Select kubeconfig interactively
		kubeconfig = selectKubeconfigInteractive()
		// 2. Select kubecontext interactively
		rawConfig, err := loadRawKubeConfig(kubeconfig)
		if err != nil {
			log.Fatalf("Failed to load kubeconfig: %v", err)
		}
		kubecontext = selectContextInteractive(rawConfig)
		// 3. Create clientset with the selected context
		clientset, err = buildClientset(kubeconfig, kubecontext)
		if err != nil {
			log.Fatalf("Failed to create Kubernetes client: %v", err)
		}
		// 4. Find all namespaces, let user select interactively
		namespace = selectNamespaceInteractive(clientset)
		// 5. Select deployment interactively
		deploymentName = selectDeploymentInteractive(clientset, namespace)
		// 6. Find all pods of this deployment, select a running one
		pod, err := selectRunningPodOfDeployment(clientset, namespace, deploymentName)
		if err != nil {
			log.Fatalf("Failed to find a running pod: %v", err)
		}
		podName = pod.Name
		nodeName = pod.Spec.NodeName
	} else {
		fmt.Println("[AUTO MODE] Running in automatic sidecar mode.")
		fmt.Println("[AUTO MODE] Attempting to load in-cluster configuration...")

		// Get kubeconfig from default location (in-cluster)
		kubeconfig = ""
		kubecontext = ""

		// Use in-cluster config
		fmt.Println("[AUTO MODE] Building config from in-cluster flags...")
		config, err := clientcmd.BuildConfigFromFlags("", "")
		if err != nil {
			log.Fatalf("[AUTO MODE] Failed to load in-cluster kubeconfig: %v", err)
		}
		fmt.Printf("[AUTO MODE] Successfully loaded in-cluster config. Host: %s\n", config.Host)

		fmt.Println("[AUTO MODE] Creating Kubernetes client...")
		clientset, err = kubernetes.NewForConfig(config)
		if err != nil {
			log.Fatalf("[AUTO MODE] Failed to create Kubernetes client: %v", err)
		}
		fmt.Println("[AUTO MODE] Successfully created Kubernetes client")

		// Get environment variables
		fmt.Println("[AUTO MODE] Reading environment variables...")
		podName = os.Getenv("POD_NAME")
		namespace = os.Getenv("NAMESPACE")
		nodeName = os.Getenv("NODE_NAME")

		fmt.Printf("[AUTO MODE] Environment variables:\n")
		fmt.Printf("  POD_NAME: %s\n", podName)
		fmt.Printf("  NAMESPACE: %s\n", namespace)
		fmt.Printf("  NODE_NAME: %s\n", nodeName)

		if podName == "" || namespace == "" || nodeName == "" {
			log.Fatalf("[AUTO MODE] POD_NAME, NAMESPACE, and NODE_NAME environment variables must be set in automatic mode.")
		}

		// Find deployment by owner reference
		fmt.Printf("[AUTO MODE] Looking up deployment for pod %s in namespace %s...\n", podName, namespace)
		deploymentName, err = findDeploymentNameByPod(clientset, namespace, podName)
		if err != nil {
			log.Fatalf("[AUTO MODE] Failed to find deployment for pod %s: %v", podName, err)
		}
		fmt.Printf("[AUTO MODE] Found deployment: %s\n", deploymentName)
	}

	// Get pod status (only needed for debug output)
	if debugMode {
		pod, err := clientset.CoreV1().Pods(namespace).Get(context.Background(), podName, metav1.GetOptions{})
		if err == nil {
			fmt.Printf("Pod status: %s\n", pod.Status.Phase)
		}
	}

	// Get Node object
	fmt.Printf("[AUTO MODE] Starting node status monitoring for node %s...\n", nodeName)

	// Configure check interval (default 5 minutes)
	checkInterval := 5 * time.Minute
	if interval := os.Getenv("CHECK_INTERVAL_MINUTES"); interval != "" {
		if minutes, err := strconv.Atoi(interval); err == nil && minutes > 0 {
			checkInterval = time.Duration(minutes) * time.Minute
			fmt.Printf("[AUTO MODE] Check interval set to %d minutes\n", minutes)
		} else {
			fmt.Printf("[AUTO MODE] Invalid CHECK_INTERVAL_MINUTES value '%s', using default 5 minutes\n", interval)
		}
	} else {
		fmt.Printf("[AUTO MODE] CHECK_INTERVAL_MINUTES not set, using default 5 minutes\n")
	}

	for {
		// Get Node object
		node, err := clientset.CoreV1().Nodes().Get(context.Background(), nodeName, metav1.GetOptions{})
		if err != nil {
			log.Printf("[AUTO MODE] Failed to get Node %s: %v", nodeName, err)
			time.Sleep(checkInterval)
			continue
		}

		cordoned := node.Spec.Unschedulable
		noSchedule := false
		var taints []corev1.Taint
		for _, t := range node.Spec.Taints {
			taints = append(taints, t)
			if t.Effect == corev1.TaintEffectNoSchedule {
				noSchedule = true
			}
		}

		fmt.Printf("[AUTO MODE] Node status check at %s:\n", time.Now().Format(time.RFC3339))
		fmt.Printf("  Node: %s\n", nodeName)
		fmt.Printf("  Cordoned (unschedulable): %v\n", cordoned)
		fmt.Printf("  Taints:\n")
		for _, t := range taints {
			fmt.Printf("    - Key: %s, Value: %s, Effect: %s\n", t.Key, t.Value, t.Effect)
		}
		fmt.Printf("  Has NoSchedule taint: %v\n", noSchedule)

		if noSchedule {
			fmt.Printf("[AUTO MODE] Node has NoSchedule taint. Restarting deployment %s...\n", deploymentName)
			if err := restartDeployment(clientset, namespace, deploymentName); err != nil {
				log.Printf("[AUTO MODE] Failed to restart deployment: %v", err)
			} else {
				fmt.Printf("[AUTO MODE] Successfully restarted deployment %s\n", deploymentName)
			}
		}

		fmt.Printf("[AUTO MODE] Next check in %v...\n", checkInterval)
		time.Sleep(checkInterval)
	}
}

// Helper to find deployment name by pod owner reference
func findDeploymentNameByPod(clientset *kubernetes.Clientset, namespace, podName string) (string, error) {
	pod, err := clientset.CoreV1().Pods(namespace).Get(context.Background(), podName, metav1.GetOptions{})
	if err != nil {
		return "", err
	}
	for _, owner := range pod.OwnerReferences {
		if owner.Kind == "ReplicaSet" {
			replicaSet, err := clientset.AppsV1().ReplicaSets(namespace).Get(context.Background(), owner.Name, metav1.GetOptions{})
			if err != nil {
				return "", err
			}
			for _, rsOwner := range replicaSet.OwnerReferences {
				if rsOwner.Kind == "Deployment" {
					return rsOwner.Name, nil
				}
			}
		}
	}
	return "", fmt.Errorf("deployment not found for pod %s", podName)
}

// --- Helper functions ---

func selectKubeconfigInteractive() string {
	// Попробовать стандартные пути
	var kubeconfigPaths []string
	if env := os.Getenv("KUBECONFIG"); env != "" {
		kubeconfigPaths = append(kubeconfigPaths, env)
	}
	if home, err := os.UserHomeDir(); err == nil {
		kubeconfigPaths = append(kubeconfigPaths, filepath.Join(home, ".kube", "config"))
	}
	kubeconfigPaths = append(kubeconfigPaths, "./kubeconfig")

	var existing []string
	for _, path := range kubeconfigPaths {
		if _, err := os.Stat(path); err == nil {
			existing = append(existing, path)
		}
	}

	fmt.Println("Выберите kubeconfig:")
	for i, path := range existing {
		fmt.Printf("%d. %s\n", i+1, path)
	}
	fmt.Printf("%d. Ввести путь вручную\n", len(existing)+1)

	choice := promptForNumber(1, len(existing)+1)
	if choice <= len(existing) {
		return existing[choice-1]
	}
	fmt.Print("Введите путь к kubeconfig: ")
	reader := bufio.NewReader(os.Stdin)
	path, _ := reader.ReadString('\n')
	path = strings.TrimSpace(path)
	if _, err := os.Stat(path); err != nil {
		log.Fatalf("Файл не найден: %s", path)
	}
	return path
}

func loadRawKubeConfig(kubeconfig string) (api.Config, error) {
	loadingRules := clientcmd.NewDefaultClientConfigLoadingRules()
	loadingRules.ExplicitPath = kubeconfig
	configOverrides := &clientcmd.ConfigOverrides{}
	return clientcmd.NewNonInteractiveDeferredLoadingClientConfig(
		loadingRules, configOverrides,
	).RawConfig()
}

func selectContextInteractive(config api.Config) string {
	var contexts []string
	for name := range config.Contexts {
		contexts = append(contexts, name)
	}
	if len(contexts) == 0 {
		log.Fatal("Нет доступных контекстов в kubeconfig")
	}
	fmt.Println("Выберите context:")
	for i, ctx := range contexts {
		current := ""
		if ctx == config.CurrentContext {
			current = " (current)"
		}
		fmt.Printf("%d. %s%s\n", i+1, ctx, current)
	}
	choice := promptForNumber(1, len(contexts))
	return contexts[choice-1]
}

func buildClientset(kubeconfig, kubecontext string) (*kubernetes.Clientset, error) {
	loadingRules := clientcmd.NewDefaultClientConfigLoadingRules()
	loadingRules.ExplicitPath = kubeconfig
	configOverrides := &clientcmd.ConfigOverrides{CurrentContext: kubecontext}
	config, err := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(
		loadingRules, configOverrides,
	).ClientConfig()
	if err != nil {
		return nil, err
	}
	return kubernetes.NewForConfig(config)
}

func selectNamespaceInteractive(clientset *kubernetes.Clientset) string {
	namespaces, err := clientset.CoreV1().Namespaces().List(context.Background(), metav1.ListOptions{})
	if err != nil {
		log.Fatalf("Ошибка получения namespaces: %v", err)
	}
	if len(namespaces.Items) == 0 {
		log.Fatal("Нет namespace в кластере")
	}
	fmt.Println("Выберите namespace:")
	for i, ns := range namespaces.Items {
		fmt.Printf("%d. %s\n", i+1, ns.Name)
	}
	choice := promptForNumber(1, len(namespaces.Items))
	return namespaces.Items[choice-1].Name
}

func selectDeploymentInteractive(clientset *kubernetes.Clientset, namespace string) string {
	deployments, err := clientset.AppsV1().Deployments(namespace).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		log.Fatalf("Ошибка получения deployments: %v", err)
	}
	if len(deployments.Items) == 0 {
		log.Fatalf("Нет deployments в namespace %s", namespace)
	}
	fmt.Println("Выберите deployment:")
	for i, d := range deployments.Items {
		fmt.Printf("%d. %s\n", i+1, d.Name)
	}
	choice := promptForNumber(1, len(deployments.Items))
	return deployments.Items[choice-1].Name
}

func selectRunningPodOfDeployment(clientset *kubernetes.Clientset, namespace, deploymentName string) (*corev1.Pod, error) {
	// Получить deployment
	deployment, err := clientset.AppsV1().Deployments(namespace).Get(context.Background(), deploymentName, metav1.GetOptions{})
	if err != nil {
		return nil, fmt.Errorf("ошибка получения deployment: %v", err)
	}
	// Получить selector
	selector := metav1.FormatLabelSelector(deployment.Spec.Selector)
	pods, err := clientset.CoreV1().Pods(namespace).List(context.Background(), metav1.ListOptions{
		LabelSelector: selector,
	})
	if err != nil {
		return nil, fmt.Errorf("ошибка получения pods: %v", err)
	}
	var runningPods []*corev1.Pod
	for i := range pods.Items {
		if pods.Items[i].Status.Phase == corev1.PodRunning {
			runningPods = append(runningPods, &pods.Items[i])
		}
	}
	if len(runningPods) == 0 {
		return nil, fmt.Errorf("нет работающих pod в deployment %s", deploymentName)
	}
	fmt.Println("Выберите работающий pod:")
	for i, pod := range runningPods {
		fmt.Printf("%d. %s\n", i+1, pod.Name)
	}
	choice := promptForNumber(1, len(runningPods))
	return runningPods[choice-1], nil
}

func promptForNumber(min, max int) int {
	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Printf("Введите номер (%d-%d): ", min, max)
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)
		num, err := strconv.Atoi(input)
		if err == nil && num >= min && num <= max {
			return num
		}
		fmt.Printf("Некорректный ввод. Введите число от %d до %d.\n", min, max)
	}
}

func restartDeployment(clientset *kubernetes.Clientset, namespace, deploymentName string) error {
	ctx := context.Background()
	deployment, err := clientset.AppsV1().Deployments(namespace).Get(ctx, deploymentName, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get deployment: %w", err)
	}
	if deployment.Spec.Template.Annotations == nil {
		deployment.Spec.Template.Annotations = map[string]string{}
	}
	deployment.Spec.Template.Annotations["kubectl.kubernetes.io/restartedAt"] = metav1.Now().Format("2006-01-02T15:04:05Z07:00")
	_, err = clientset.AppsV1().Deployments(namespace).Update(ctx, deployment, metav1.UpdateOptions{})
	if err != nil {
		return fmt.Errorf("failed to update deployment: %w", err)
	}
	return nil
}
