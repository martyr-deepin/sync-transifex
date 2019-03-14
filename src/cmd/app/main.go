package main

import (
	"bytes"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/codeskyblue/go-sh"
)

var (
	flagDebug   bool
	flagPush    bool
	flagPull    bool
	flagForce bool
	flagRepoDir string
	flagOwner string
)

func init() {
	flag.BoolVar(&flagDebug, "debug", false, "debug mode")
	flag.BoolVar(&flagPush, "push", false, "")
	flag.BoolVar(&flagPull, "pull", false, "")
	flag.StringVar(&flagRepoDir, "repo-dir", "/tmp", "")
	flag.BoolVar(&flagForce, "force", false, "")
	flag.StringVar(&flagOwner, "owner", "linuxdeepin", "github project owner")
}

func cloneRepo(project, branch string, shallow bool) error {
	url := fmt.Sprintf("https://gitlab.deepin.io/github-linuxdeepin-mirror/%s.git",
		project)
	session := sh.NewSession()
	session.SetDir(flagRepoDir)
	log.Println("clone from", url)
	gitArgs := []string{"clone", "-b", branch}
	if shallow {
		gitArgs = append(gitArgs, "--depth", "1")
	}
	gitArgs = append(gitArgs, url)
	err := session.Command("git", gitArgs).Run()
	return err
}

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)
	flag.Parse()
	var project string
	branch := "master"
	projectAndBranch := flag.Arg(0)
	if strings.Contains(projectAndBranch, "@") {
		fields := strings.SplitN(projectAndBranch, "@", 2)
		project = fields[0]
		branch = fields[1]
	} else {
		project = projectAndBranch
	}

	if project == "" {
		log.Fatal("empty project")
	}
	if branch == "" {
		log.Fatal("empty branch")
	}
	log.Println("project:", project)
	log.Println("branch:", branch)
	log.Println("repos dir:", flagRepoDir)

	stat, err := os.Stat(flagRepoDir)
	if err != nil {
		log.Fatal(err)
	}
	if !stat.IsDir() {
		log.Fatal("repos dir is not a dir")
	}

	if flagPush {
		err := pushTranslationSource(project, branch)
		if err != nil {
			log.Fatal(err)
		}
	} else if flagPull {
		err := pullTranslationResult(project, branch)
		if err != nil {
			log.Fatal(err)
		}
	}
}

func writeTransifexRc() error {
	username := os.Getenv("TX_USER")
	password := os.Getenv("TX_PASSWORD")
	str := fmt.Sprintf(`
[https://www.transifex.com]
api_hostname = https://api.transifex.com
hostname = https://www.transifex.com
username = %s
password = %s
`, username, password)
	home := os.Getenv("HOME")
	return ioutil.WriteFile(filepath.Join(home, ".transifexrc"), []byte(str), 0600)
}

func removeTransifexRc() error {
	home := os.Getenv("HOME")
	return os.Remove(filepath.Join(home, ".transifexrc"))
}

func writeGitCredential() error {
	username := os.Getenv("GITHUB_USER")
	password := os.Getenv("GITHUB_PASSWORD")
	str := fmt.Sprintf("https://%s:%s@github.com", username, password)
	home := os.Getenv("HOME")
	return ioutil.WriteFile(filepath.Join(home, ".git-credentials"), []byte(str), 0600)
}

func removeGitCredential() error {
	home := os.Getenv("HOME")
	return os.Remove(filepath.Join(home, ".git-credentials"))
}

func removeHubConfig() error {
	home := os.Getenv("HOME")
	err := os.Remove(filepath.Join(home, ".config/hub"))
	if os.IsNotExist(err) {
		// ignore not exist error
		err = nil
	}
	return err
}

// 上传翻译源文件
func pushTranslationSource(project, branch string) error {
	err := writeTransifexRc()
	if err != nil {
		return err
	}
	defer removeTransifexRc()

	dir := filepath.Join(flagRepoDir, project)
	err = os.RemoveAll(dir)
	if err != nil {
		return err
	}

	err = cloneRepo(project, branch, true)
	if err != nil {
		return err
	}

	err = os.Chdir(dir)
	if err != nil {
		return err
	}

	txArgs := []string{"push", "-s",
		"--skip", "--no-interactive"}
	if flagForce {
		txArgs = append(txArgs, "-f")
	}
	err = sh.Command("tx", txArgs).Run()
	return err
}

// 下载翻译结果文件
func pullTranslationResult(project, branch string) error {
	err := writeTransifexRc()
	if err != nil {
		return err
	}
	defer removeTransifexRc()

	dir := filepath.Join(flagRepoDir, project)
	err = os.RemoveAll(dir)
	if err != nil {
		return err
	}

	err = cloneRepo(project, branch, false)
	if err != nil {
		return err
	}

	err = os.Chdir(dir)
	if err != nil {
		return err
	}

	txArgs := []string{"pull", "-a", "--minimum-perc", "1"}
	if flagForce {
		txArgs = append(txArgs, "-f")
	}
	if flagDebug {
		txArgs = append(txArgs, "--pseudo")
	}

	err = sh.Command("tx", txArgs).Run()
	if err != nil {
		return err
	}

	err = convertTs2Desktop()
	if err != nil {
		return err
	}

	err = addFiles()
	if err != nil {
		return err
	}

	// configure git
	originUrl := fmt.Sprintf("https://github.com/%s/%s", flagOwner, project)
	err = sh.Command("git", "remote", "set-url", "origin", originUrl).Run()
	if err != nil {
		return err
	}

	githubUser := os.Getenv("GITHUB_USER")
	configMap := map[string]string{
		"user.name": githubUser,
		"user.email": os.Getenv("GITHUB_EMAIL"),
		"hub.protocol": "https",
		"credential.helper": "store",
	}
	for key, value := range configMap {
		err = sh.Command("git", "config", "--local", key, value).Run()
		if err != nil {
			return err
		}
	}

	err = writeGitCredential()
	if err != nil {
		return err
	}
	err = sh.Command("pkill","-e", "git-credential-").Run()
	if err != nil {
		log.Println("pkill err:", err)
	}

	err = removeHubConfig()
	if err != nil {
		return err
	}

	defer removeGitCredential()

	devBranch := branch +"+update-tr"
	err = sh.Command("git", "checkout", "-b", devBranch).Run()
	if err != nil {
		return err
	}

	commitMessage := "chore: auto pull translation files from transifex"
	err = sh.Command("git", "commit",
		"-m", commitMessage).Run()
	if err != nil {
		return err
	}

	// fork
	err = sh.Command("hub", "fork", "--remote-name", "fork").Run()
	if err != nil {
		return err
	}

	// push devBranch to my fork repo
	err = sh.Command("git", "push", "fork", devBranch + ":" + devBranch, "-f").Run()
	if err != nil {
		return err
	}

	prHead := githubUser+":"+devBranch
	output, err := sh.Command("hub", "pr", "list",
		"-h", prHead, "-b", branch, "-f", "%t%n").Output()
	if bytes.Contains(output, []byte(commitMessage)) {
			log.Println("has pull request")

	} else {
			log.Println("create new pull request")
			err = sh.Command("hub", "pull-request",
				"-b", branch,
				"-h", prHead,
				"-m", commitMessage).Run()
			if err != nil {
				return err
			}
	}

	return nil
}

// 加载 .tx/ts2desktop 文件
func loadTs2DesktopConfig(filename string) (map[string]string, error) {
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	result := make(map[string]string)
	lines := bytes.Split(data, []byte("\n"))
	for _, line := range lines {
		line = bytes.TrimSpace(line)
		parts := bytes.SplitN(line, []byte("="), 2)
		if len(parts) != 2 {
			continue
		}
		result[string(parts[0])] = string(parts[1])
	}
	return result, nil
}

func convertTs2Desktop() error {
	// workDir: project dir
	cfg, err := loadTs2DesktopConfig(".tx/ts2desktop")
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}

	sourceFile := cfg["DESKTOP_SOURCE_FILE"]
	tsDir := cfg["DESKTOP_TS_DIR"]
	tempFile := cfg["DESKTOP_TEMP_FILE"]
	destFile := cfg["DESKTOP_DEST_FILE"]

	err = sh.Command("deepin-desktop-ts-convert", "ts2desktop",
		sourceFile, tsDir, tempFile).Run()
	if err != nil {
		return err
	}
	err = os.Rename(tempFile, destFile)
	if err != nil {
		return err
	}

	err = sh.Command("git", "add", destFile).Run()
	return err
}

func addFiles() error {
	// workDir: project dir
	err := filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() && info.Name() == ".git" {
			return filepath.SkipDir
		}

		if info.IsDir() {
			return nil
		}

		ext := filepath.Ext(info.Name())
		switch ext {
		case ".ts", ".po":
			log.Println("git add", path)
			err = sh.Command("git", "add",
				path).Run()
			if err != nil {
				return err
			}
		}
		return nil
	})
	return err
}
