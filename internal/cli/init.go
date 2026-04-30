package cli

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

func defaultInitFeatures() []string {
	return []string{"rtc", "convoai"}
}

func initNextSteps(template quickstartTemplate, targetDir string) []string {
	dir := filepath.Base(targetDir)
	steps := []string{"cd " + dir}
	if template.InstallCommand != "" {
		steps = append(steps, template.InstallCommand)
	}
	if template.RunCommand != "" {
		steps = append(steps, template.RunCommand)
	}
	return steps
}

func (a *App) buildInitCommand() *cobra.Command {
	var templateID string
	var dir string
	var existingProject string
	var region string
	var features []string
	var newProject bool
	cmd := &cobra.Command{
		Use:   "init <name>",
		Short: "Create a project, clone a quickstart, and write env in one flow",
		Long: `Init is the recommended onboarding command.

By default it reuses your existing Agora project — preferring one named "Default Project", then falling back to the most recent project. A new project is only created when no projects exist yet or when --new-project is passed.

Use --project to bind to a specific existing project by name or ID.
Use --new-project to always create a fresh project regardless of existing ones.
Use --feature to specify which features to enable on a newly created project (repeatable).`,
		Example: example(`
  agora init my-nextjs-demo --template nextjs
  agora init my-python-demo --template python
  agora init my-go-demo --template go --project my-existing-project
  agora init my-rtm-demo --template nextjs --new-project --feature rtc --feature rtm
`),
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) != 1 || strings.TrimSpace(args[0]) == "" {
				return fmt.Errorf("project name is required")
			}
			if strings.TrimSpace(templateID) == "" {
				selected, err := a.selectInitTemplate(cmd)
				if err != nil {
					return err
				}
				templateID = selected
			}
			template, ok := findQuickstartTemplate(templateID)
			if !ok {
				return &cliError{Message: fmt.Sprintf("unknown quickstart template %q. Run `agora quickstart list` to see available templates.", templateID), Code: "QUICKSTART_TEMPLATE_UNKNOWN"}
			}
			targetDir := dir
			if strings.TrimSpace(targetDir) == "" {
				targetDir = args[0]
			}
			// Interactive reuse confirmation: only when TTY+pretty+not-CI, no
			// explicit --project, and not --new-project. Silent reuse stays the
			// default for --json / CI / non-TTY agent runs.
			promptForReuse := strings.TrimSpace(existingProject) == "" &&
				!newProject &&
				a.resolveOutputMode(cmd) != outputJSON &&
				!isCIEnvironment(a.osEnv) &&
				isTTY(os.Stdin)
			progress := jsonProgressFor(a, cmd, "init")
			result, err := a.initProject(args[0], targetDir, *template, existingProject, region, features, newProject, promptForReuse, cmd.ErrOrStderr(), os.Stdin, progress)
			if err != nil {
				return err
			}
			return renderResult(cmd, "init", result)
		},
	}
	cmd.Flags().StringVar(&templateID, "template", "", "quickstart template ID to use")
	cmd.Flags().StringVar(&dir, "dir", "", "target directory for the cloned quickstart; defaults to <name>")
	cmd.Flags().StringVar(&existingProject, "project", "", "existing project ID or exact project name to bind to")
	cmd.Flags().StringVar(&region, "region", "", "control plane region for newly created projects (global or cn)")
	cmd.Flags().StringArrayVar(&features, "feature", nil, "enable a feature on the newly created project (repeatable); defaults to rtc and convoai")
	cmd.Flags().BoolVar(&newProject, "new-project", false, "always create a new Agora project instead of reusing an existing one")
	return cmd
}

func (a *App) selectInitTemplate(cmd *cobra.Command) (string, error) {
	if a.resolveOutputMode(cmd) == outputJSON || isCIEnvironment(a.osEnv) || !isTTY(os.Stdin) {
		return "", &cliError{Message: "quickstart template is required. Pass `--template` or run `agora quickstart list`.", Code: "QUICKSTART_TEMPLATE_REQUIRED"}
	}
	templates := []quickstartTemplate{}
	for _, template := range quickstartTemplates() {
		if template.Available && template.SupportsInit {
			templates = append(templates, template)
		}
	}
	if len(templates) == 0 {
		return "", &cliError{Message: "no init-compatible quickstart templates are available.", Code: "QUICKSTART_TEMPLATE_UNAVAILABLE"}
	}
	out := cmd.ErrOrStderr()
	fmt.Fprintln(out, "Choose a quickstart template:")
	for index, template := range templates {
		fmt.Fprintf(out, "  %d. %s (%s)\n", index+1, template.ID, template.Title)
	}
	fmt.Fprint(out, "Template: ")
	reader := bufio.NewReader(os.Stdin)
	answer, err := reader.ReadString('\n')
	if err != nil && !errors.Is(err, io.EOF) {
		return "", err
	}
	answer = strings.TrimSpace(answer)
	if answer == "" {
		return templates[0].ID, nil
	}
	if index, err := strconv.Atoi(answer); err == nil && index >= 1 && index <= len(templates) {
		return templates[index-1].ID, nil
	}
	if _, ok := findQuickstartTemplate(answer); ok {
		return answer, nil
	}
	return "", &cliError{Message: fmt.Sprintf("unknown quickstart template %q. Run `agora quickstart list` to see available templates.", answer), Code: "QUICKSTART_TEMPLATE_UNKNOWN"}
}

func parseInitProjectTimestamp(value string) (time.Time, bool) {
	if strings.TrimSpace(value) == "" {
		return time.Time{}, false
	}
	for _, layout := range []string{time.RFC3339Nano, time.RFC3339} {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed, true
		}
	}
	return time.Time{}, false
}

func selectInitProjectFromList(items []projectSummary) (projectSummary, bool) {
	if len(items) == 0 {
		return projectSummary{}, false
	}
	for _, item := range items {
		if item.Name == "Default Project" {
			return item, true
		}
	}
	selected := items[0]
	selectedCreated, selectedCreatedOK := parseInitProjectTimestamp(selected.CreatedAt)
	selectedUpdated, selectedUpdatedOK := parseInitProjectTimestamp(selected.UpdatedAt)
	for _, item := range items[1:] {
		itemCreated, itemCreatedOK := parseInitProjectTimestamp(item.CreatedAt)
		switch {
		case itemCreatedOK && !selectedCreatedOK:
			selected = item
			selectedCreated = itemCreated
			selectedCreatedOK = true
			selectedUpdated, selectedUpdatedOK = parseInitProjectTimestamp(item.UpdatedAt)
			continue
		case !itemCreatedOK || !selectedCreatedOK:
			continue
		case itemCreated.After(selectedCreated):
			selected = item
			selectedCreated = itemCreated
			selectedUpdated, selectedUpdatedOK = parseInitProjectTimestamp(item.UpdatedAt)
			continue
		case !itemCreated.Equal(selectedCreated):
			continue
		}
		itemUpdated, itemUpdatedOK := parseInitProjectTimestamp(item.UpdatedAt)
		switch {
		case itemUpdatedOK && !selectedUpdatedOK:
			selected = item
			selectedCreated = itemCreated
			selectedUpdated = itemUpdated
			selectedUpdatedOK = true
		case itemUpdatedOK && selectedUpdatedOK && itemUpdated.After(selectedUpdated):
			selected = item
			selectedCreated = itemCreated
			selectedUpdated = itemUpdated
		case itemUpdatedOK == selectedUpdatedOK && item.ProjectID > selected.ProjectID:
			selected = item
			selectedCreated = itemCreated
			selectedUpdated = itemUpdated
			selectedUpdatedOK = itemUpdatedOK
		}
	}
	return selected, true
}

// findDefaultProject returns the user's preferred existing project: "Default Project" if it
// exists, otherwise the most recently created project in the current results page. Returns
// found=false when the account has no projects yet. The total count returned is the number
// of projects in the listing, so callers can decide whether silent reuse is risky enough to
// warrant a confirmation prompt.
func (a *App) findDefaultProject() (target projectTarget, found bool, total int, err error) {
	ctx, err := loadContext(a.env)
	if err != nil {
		return projectTarget{}, false, 0, err
	}
	list, err := a.listProjects("", 1, 100)
	if err != nil {
		return projectTarget{}, false, 0, err
	}
	total = len(list.Items)
	if total == 0 {
		return projectTarget{}, false, 0, nil
	}
	item, ok := selectInitProjectFromList(list.Items)
	if !ok {
		return projectTarget{}, false, total, nil
	}
	project, err := a.getProject(item.ProjectID)
	if err != nil {
		return projectTarget{}, false, total, err
	}
	region := ctx.CurrentRegion
	if region == "" {
		region = "global"
	}
	if item.Region != nil && *item.Region != "" {
		region = *item.Region
	}
	if project.Region != nil && *project.Region != "" {
		region = *project.Region
	}
	return projectTarget{project: project, region: region}, true, total, nil
}

// confirmProjectReuse prompts the user before silently binding a new repo to a
// reused project. Returns one of "reuse", "new", or "abort". Empty input or 'y'
// defaults to "reuse"; 'n' aborts; 'new' or 'c' creates a fresh project.
func confirmProjectReuse(in io.Reader, out io.Writer, name, projectID string) (string, error) {
	reader := bufio.NewReader(in)
	prompt := fmt.Sprintf("Use existing project %q (%s)? [Y/n/new]: ", name, projectID)
	for {
		if _, err := fmt.Fprint(out, prompt); err != nil {
			return "", err
		}
		answer, err := reader.ReadString('\n')
		if err != nil && !errors.Is(err, io.EOF) {
			return "", err
		}
		switch strings.ToLower(strings.TrimSpace(answer)) {
		case "", "y", "yes":
			return "reuse", nil
		case "n", "no":
			return "abort", nil
		case "new", "c", "create":
			return "new", nil
		}
		if _, err := fmt.Fprintln(out, "Please answer y (reuse), n (abort), or new (create a fresh project)."); err != nil {
			return "", err
		}
		if errors.Is(err, io.EOF) {
			return "abort", nil
		}
	}
}

func (a *App) initProject(name, targetDir string, template quickstartTemplate, existingProject, region string, features []string, newProject bool, promptForReuse bool, promptOut io.Writer, promptIn io.Reader, progress progressEmitter) (map[string]any, error) {
	var target projectTarget
	projectAction := "existing"
	enabledFeatures := []string{}
	needsCreate := false

	switch {
	case strings.TrimSpace(existingProject) != "":
		resolved, err := a.resolveProjectTarget(existingProject)
		if err != nil {
			return nil, err
		}
		target = resolved
	case newProject:
		needsCreate = true
	default:
		resolved, found, total, err := a.findDefaultProject()
		if err != nil {
			return nil, err
		}
		if found {
			// Confirm reuse only if more than one project exists; if the
			// account has exactly one project, silent reuse is unambiguous.
			if promptForReuse && total > 1 {
				choice, err := confirmProjectReuse(promptIn, promptOut, resolved.project.Name, resolved.project.ProjectID)
				if err != nil {
					return nil, err
				}
				switch choice {
				case "abort":
					return nil, &cliError{Message: "init aborted by user.", Code: "INIT_ABORTED"}
				case "new":
					needsCreate = true
				default:
					target = resolved
				}
			} else {
				target = resolved
			}
		} else {
			needsCreate = true
		}
	}

	if needsCreate {
		featuresToEnable := features
		if len(featuresToEnable) == 0 {
			featuresToEnable = defaultInitFeatures()
		}
		progress.emit("project:create", "Creating Agora project", map[string]any{"projectName": name, "features": featuresToEnable})
		projectResult, err := a.projectCreate(name, region, "", featuresToEnable, "")
		if err != nil {
			return nil, err
		}
		projectAction = "created"
		if list, ok := projectResult["enabledFeatures"].([]string); ok {
			enabledFeatures = list
		}
		resolved, err := a.resolveProjectTarget(asString(projectResult["projectId"]))
		if err != nil {
			return nil, err
		}
		target = resolved
		progress.emit("project:created", "Agora project ready", map[string]any{"projectId": target.project.ProjectID, "projectName": target.project.Name})
	} else {
		progress.emit("project:reuse", "Reusing existing Agora project", map[string]any{"projectId": target.project.ProjectID, "projectName": target.project.Name})
	}

	quickstartResult, err := a.quickstartCreate(template, targetDir, target.project.ProjectID, "", progress)
	if err != nil {
		return nil, err
	}

	ctx, err := loadContext(a.env)
	if err != nil {
		return nil, err
	}
	ctx.CurrentProjectID = &target.project.ProjectID
	ctx.CurrentProjectName = &target.project.Name
	ctx.CurrentRegion = target.region
	if ctx.PreferredRegion == "" {
		ctx.PreferredRegion = target.region
	}
	if err := saveContext(a.env, ctx); err != nil {
		return nil, err
	}

	result := map[string]any{
		"action":                "init",
		"enabledFeatures":       enabledFeatures,
		"envPath":               quickstartResult["envPath"],
		"metadataPath":          filepath.ToSlash(filepath.Join(localAgoraDirName, localProjectFileName)),
		"nextSteps":             initNextSteps(template, asString(quickstartResult["path"])),
		"path":                  quickstartResult["path"],
		"projectAction":         projectAction,
		"projectId":             target.project.ProjectID,
		"projectName":           target.project.Name,
		"region":                target.region,
		"reusedExistingProject": projectAction == "existing",
		"status":                "ready",
		"template":              template.ID,
		"title":                 template.Title,
	}
	return result, nil
}
