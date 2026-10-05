#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import vm from "node:vm";

const DEFAULT_REMOTE_URL = "git@gitlab.ninebot.com:ninebotapp/platform/app-docs.git";
const DEFAULT_BASE_BRANCH = "main";
const DEFAULT_BRANCH_PREFIX = "skill-contrib/";
const DEFAULT_INSTALL_TARGETS = ["copilot", "claude", "codex"];
const SUPPORTED_UPDATE_KINDS = new Set(["metadata", "docs", "source", "zip"]);
const REQUIRED_METADATA_FIELDS = [
  "name",
  "description",
  "summary",
  "tags",
  "platforms",
  "version",
  "owner",
];
const COPY_EXCLUDES = new Set([
  ".DS_Store",
  "__MACOSX",
  "__pycache__",
  "node_modules",
  ".git",
  ".idea",
  ".vscode",
  "dist",
  "build",
]);
const ZIP_EXCLUDES = [
  "*.DS_Store",
  "__MACOSX/*",
  "*/__pycache__/*",
  "*/node_modules/*",
  "*/.git/*",
  "*/dist/*",
  "*/build/*",
];

main();

function main() {
  try {
    const { command, options } = parseArgs(process.argv.slice(2));

    if (!command || options.help) {
      printHelp();
      return;
    }

    if (command === "init-manifest") {
      initManifest(options);
      return;
    }

    if (command === "apply") {
      applyManifest(options);
      return;
    }

    fail(`Unsupported command: ${command}`);
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
  }
}

function printHelp() {
  console.log(`Skill Hub Contributor

Usage:
  node contribute-skill.mjs init-manifest --mode add --output /tmp/skill.json
  node contribute-skill.mjs apply --manifest /tmp/skill.json [--check-only] [--resume] [--push]

Commands:
  init-manifest   Generate a manifest template for add or update mode.
  apply           Apply a manifest to app-docs, validate, and create a local commit. Use --push to create a draft MR.

Options:
  --mode <mode>       Manifest mode for init-manifest. Allowed: add, update.
  --output <path>     Target path for init-manifest output.
  --manifest <path>   Manifest JSON path for apply.
  --check-only        Update files and run validation only. Do not commit or push.
  --resume            Continue on the current skill-contrib branch without resetting to main.
  --push              Push the current skill-contrib branch and create a draft MR.
  --help              Show this help text.
`);
}

function parseArgs(argv) {
  const [command, ...rest] = argv;
  const options = { _: [] };

  for (let index = 0; index < rest.length; index += 1) {
    const arg = rest[index];

    if (arg === "--help") {
      options.help = true;
      continue;
    }

    if (arg === "--skip-push") {
      options.skipPush = true;
      continue;
    }

    if (arg === "--push") {
      options.push = true;
      continue;
    }

    if (arg === "--check-only") {
      options.checkOnly = true;
      continue;
    }

    if (arg === "--resume") {
      options.resume = true;
      continue;
    }

    if (arg === "--mode" || arg === "--output" || arg === "--manifest") {
      const value = rest[index + 1];
      if (!value || value.startsWith("--")) {
        fail(`Missing value for ${arg}`);
      }
      options[arg.slice(2)] = value;
      index += 1;
      continue;
    }

    options._.push(arg);
  }

  return { command, options };
}

function initManifest(options) {
  const mode = options.mode ?? "add";
  if (mode !== "add" && mode !== "update") {
    fail(`Unsupported mode for init-manifest: ${mode}`);
  }

  const outputPath = options.output
    ? path.resolve(process.cwd(), options.output)
    : path.resolve(process.cwd(), `${mode}-skill-manifest.json`);

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(buildManifestTemplate(mode), null, 2) + "\n");
  console.log(`Manifest template written to ${outputPath}`);
}

function applyManifest(options) {
  const manifestOption = options.manifest ?? options._[0];
  if (!manifestOption) {
    fail("Missing --manifest path");
  }

  ensureCommand("git");
  ensureCommand("node");

  const manifestPath = path.resolve(process.cwd(), manifestOption);
  const manifest = normalizeManifest(readJsonFile(manifestPath), manifestPath);
  const repoState = prepareRepository(manifest, options);
  const repoRoot = repoState.repoRoot;
  const workingBranch =
    repoState.workingBranch ?? checkoutWorkingBranch(repoRoot, manifest.slug);
  const commitMessage =
    manifest.mode === "add"
      ? `feat(skill-hub): add ${manifest.slug}`
      : `chore(skill-hub): update ${manifest.slug}`;

  if (options.resume && options.push && branchHasLocalCommits(repoRoot) && !gitWorkingTreeDirty(repoRoot)) {
    console.log(`Pushing existing local commit(s) from ${workingBranch}.`);
    pushDraftMergeRequest(repoRoot, workingBranch, commitMessage, manifestPath);
    console.log(`Draft MR created from ${workingBranch}`);
    console.log(`Repository: ${repoRoot}`);
    return;
  }

  const changedPaths = updateRepositoryFromManifest(repoRoot, manifest, options);

  runValidation(repoRoot, workingBranch, manifestPath);

  if (options.checkOnly) {
    console.log(`Local validation passed for ${manifest.slug}.`);
    console.log(`Repository: ${repoRoot}`);
    console.log(`Branch: ${workingBranch}`);
    console.log("No commit or push was created because --check-only was used.");
    console.log(`Continue with: ${buildApplyCommand(manifestPath, { resume: true })}`);
    return;
  }

  stagePaths(repoRoot, changedPaths);

  if (!hasStagedChanges(repoRoot)) {
    if (options.resume && branchHasLocalCommits(repoRoot)) {
      console.log(`No new file changes were produced for ${manifest.slug}; reusing existing local commit(s).`);
    } else {
      fail(
        `No repository changes were produced for ${manifest.slug}. ` +
          `If this repo came from a previous failed run, fix the manifest or sourceDir and rerun with --resume.`,
      );
    }
  }

  if (hasStagedChanges(repoRoot)) {
    runCommand("git", ["commit", "-m", commitMessage], { cwd: repoRoot });
  }

  if (!options.push || options.skipPush) {
    console.log(`Local branch is ready on ${workingBranch}.`);
    console.log(`Repository: ${repoRoot}`);
    console.log("Push was not executed. Ask the user whether to push this branch.");
    console.log(`Continue with: ${buildApplyCommand(manifestPath, { resume: true, push: true })}`);
    console.log(`Or push manually: git push -u origin ${workingBranch}`);
    return;
  }

  pushDraftMergeRequest(repoRoot, workingBranch, commitMessage, manifestPath);

  console.log(`Draft MR created from ${workingBranch}`);
  console.log(`Repository: ${repoRoot}`);
}

function buildManifestTemplate(mode) {
  const today = formatDate(new Date());

  if (mode === "update") {
    return {
      mode: "update",
      repoPath: "",
      slug: "",
      sourceDir: "",
      updatedAt: today,
      updateKinds: ["metadata"],
      summary: "",
      docSections: [
        {
          title: "推荐使用流程",
          markdown: "- 第一步\n- 第二步",
        },
      ],
    };
  }

  return {
    mode: "add",
    repoPath: "",
    slug: "",
    sourceDir: "",
    name: "",
    description: "",
    summary: "",
    tags: ["contribution", "automation"],
    platforms: ["Docusaurus", "GitLab"],
    installTargets: [...DEFAULT_INSTALL_TARGETS],
    version: "0.1.0",
    owner: "",
    updatedAt: today,
    repoUrl: "",
    featured: false,
    docSections: [
      {
        title: "技能简介",
        markdown: "说明这个 skill 解决什么问题。",
      },
      {
        title: "快速开始",
        markdown: "```bash\nexample command\n```",
      },
    ],
  };
}

function normalizeManifest(rawManifest, manifestPath) {
  if (!rawManifest || typeof rawManifest !== "object" || Array.isArray(rawManifest)) {
    fail("Manifest must be a JSON object");
  }

  const manifestDir = path.dirname(manifestPath);
  const mode = String(rawManifest.mode ?? "").trim();
  const slug = String(rawManifest.slug ?? "").trim();

  if (mode !== "add" && mode !== "update") {
    fail(`Manifest mode must be "add" or "update", received "${mode || "<empty>"}"`);
  }

  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug)) {
    fail(`Manifest slug must be kebab-case, received "${slug || "<empty>"}"`);
  }

  const repoPath = resolveOptionalPath(rawManifest.repoPath, manifestDir) ?? defaultRepoPath();
  const sourceDir = resolveOptionalPath(rawManifest.sourceDir, manifestDir);
  const installTargets = Object.prototype.hasOwnProperty.call(rawManifest, "installTargets")
    ? normalizeInstallTargets(rawManifest.installTargets)
    : mode === "add"
    ? [...DEFAULT_INSTALL_TARGETS]
    : undefined;
  const updateKinds = normalizeUpdateKinds(rawManifest.updateKinds, mode);
  const docSections = normalizeDocSections(rawManifest.docSections);
  const normalized = {
    mode,
    repoPath,
    slug,
    sourceDir,
    name: normalizeOptionalString(rawManifest.name),
    description: normalizeOptionalString(rawManifest.description),
    summary: normalizeOptionalString(rawManifest.summary),
    tags: normalizeOptionalStringList(rawManifest.tags),
    platforms: normalizeOptionalStringList(rawManifest.platforms),
    installTargets,
    version: normalizeOptionalString(rawManifest.version),
    owner: normalizeOptionalString(rawManifest.owner),
    updatedAt: normalizeDateString(rawManifest.updatedAt),
    repoUrl: normalizeNullableString(rawManifest, "repoUrl"),
    featured:
      rawManifest.featured === undefined ? undefined : Boolean(rawManifest.featured),
    docSections,
    updateKinds,
  };

  validateManifestShape(normalized);
  return normalized;
}

function validateManifestShape(manifest) {
  const needsSource = manifest.mode === "add" || manifest.updateKinds.has("source");
  const needsDocs = manifest.mode === "add" || manifest.updateKinds.has("docs");
  const needsMetadata = manifest.mode === "add" || manifest.updateKinds.has("metadata");

  if (needsSource && !manifest.sourceDir) {
    fail(`Manifest for ${manifest.slug} requires sourceDir`);
  }

  if (needsDocs && manifest.docSections.length === 0) {
    fail(`Manifest for ${manifest.slug} requires docSections`);
  }

  if (manifest.mode === "update" && manifest.updateKinds.size === 0) {
    fail("Update manifest must declare at least one updateKind");
  }

  if (needsMetadata) {
    for (const field of REQUIRED_METADATA_FIELDS) {
      if (manifest.mode === "add" && isMissingMetadataField(manifest, field)) {
        fail(`Manifest for ${manifest.slug} is missing ${field}`);
      }
    }
  }

  if (manifest.sourceDir) {
    validateSourceDirectory(manifest.sourceDir, manifest.slug);
  }
}

function prepareRepository(manifest, options) {
  const repoRoot = manifest.repoPath;
  const gitDir = path.join(repoRoot, ".git");

  if (!fs.existsSync(gitDir)) {
    fs.mkdirSync(path.dirname(repoRoot), { recursive: true });
    runCommand("git", ["clone", DEFAULT_REMOTE_URL, repoRoot], { cwd: process.cwd() });
  }

  if (!fs.existsSync(gitDir)) {
    fail(`Repository path is not a git repository: ${repoRoot}`);
  }

  ensureDependencies(repoRoot);

  if (options.resume) {
    return prepareResumeRepository(repoRoot, manifest.slug);
  }

  if (gitWorkingTreeDirty(repoRoot)) {
    fail(
      `Repository working tree is not clean: ${repoRoot}\n` +
        `If this repo contains a previous failed skill-hub-contributor run, rerun with --resume on that branch.`,
    );
  }

  runCommand("git", ["fetch", "origin"], { cwd: repoRoot });

  if (localBranchExists(repoRoot, DEFAULT_BASE_BRANCH)) {
    runCommand("git", ["switch", DEFAULT_BASE_BRANCH], { cwd: repoRoot });
  } else {
    runCommand("git", ["switch", "-c", DEFAULT_BASE_BRANCH, "--track", `origin/${DEFAULT_BASE_BRANCH}`], {
      cwd: repoRoot,
    });
  }

  runCommand("git", ["pull", "--ff-only", "origin", DEFAULT_BASE_BRANCH], { cwd: repoRoot });

  if (gitWorkingTreeDirty(repoRoot)) {
    fail(`Repository became dirty before changes were applied: ${repoRoot}`);
  }

  return { repoRoot, workingBranch: null };
}

function prepareResumeRepository(repoRoot, slug) {
  const workingBranch = currentBranchName(repoRoot);

  if (!workingBranch) {
    fail(`--resume requires an existing local branch in ${repoRoot}`);
  }

  if (workingBranch === DEFAULT_BASE_BRANCH) {
    fail(
      `--resume cannot run on ${DEFAULT_BASE_BRANCH}. Switch back to the previous ${DEFAULT_BRANCH_PREFIX}<slug>-<timestamp> branch first.`,
    );
  }

  if (!workingBranch.startsWith(`${DEFAULT_BRANCH_PREFIX}${slug}-`)) {
    fail(
      `--resume requires the current branch to match ${DEFAULT_BRANCH_PREFIX}${slug}-<timestamp>, found ${workingBranch}.`,
    );
  }

  return { repoRoot, workingBranch };
}

function checkoutWorkingBranch(repoRoot, slug) {
  const timestamp = formatTimestamp(new Date());
  const branchName = `${DEFAULT_BRANCH_PREFIX}${slug}-${timestamp}`;
  runCommand("git", ["switch", "-c", branchName], { cwd: repoRoot });
  return branchName;
}

function updateRepositoryFromManifest(repoRoot, manifest, options) {
  const skillsFilePath = path.join(repoRoot, "src/data/skills.ts");
  const registryFilePath = path.join(repoRoot, "static/files/skills/registry.json");
  const docFilePath = path.join(repoRoot, "docs/skills", `${manifest.slug}.md`);
  const sourceDirectoryPath = path.join(repoRoot, "skills_hub", manifest.slug);
  const zipFilePath = path.join(repoRoot, "static/files/skills", `${manifest.slug}.zip`);

  const currentSkills = loadSkillItems(skillsFilePath);
  const skillIndex = currentSkills.findIndex((item) => item.slug === manifest.slug);

  if (manifest.mode === "add" && skillIndex !== -1 && !options.resume) {
    fail(`Skill ${manifest.slug} already exists in src/data/skills.ts`);
  }

  if (manifest.mode === "update" && skillIndex === -1) {
    fail(`Skill ${manifest.slug} does not exist in src/data/skills.ts`);
  }

  const sourceChanged = manifest.mode === "add" || manifest.updateKinds.has("source");
  const zipChanged =
    manifest.mode === "add" || manifest.updateKinds.has("zip") || manifest.updateKinds.has("source");
  const docsChanged = manifest.mode === "add" || manifest.updateKinds.has("docs");
  const metadataChanged = manifest.mode === "add" || manifest.updateKinds.has("metadata");

  const existingSkill = skillIndex === -1 ? null : currentSkills[skillIndex];
  const finalSkill = buildFinalSkillItem(existingSkill, manifest);
  const changedPaths = [];

  if (sourceChanged) {
    syncSourceDirectory(manifest.sourceDir, sourceDirectoryPath);
    changedPaths.push(path.relative(repoRoot, sourceDirectoryPath));
  }

  if (zipChanged) {
    packageSkillZip(repoRoot, manifest.slug);
    changedPaths.push(path.relative(repoRoot, zipFilePath));
  }

  if (docsChanged) {
    writeSkillDoc(docFilePath, finalSkill, manifest.docSections);
    changedPaths.push(path.relative(repoRoot, docFilePath));
  }

  if (metadataChanged) {
    const updatedSkills =
      manifest.mode === "add" && skillIndex === -1
        ? [...currentSkills, finalSkill]
        : currentSkills.map((item, index) => (index === skillIndex ? finalSkill : item));

    writeSkillsFile(skillsFilePath, updatedSkills);
    writeRegistryFile(registryFilePath, updatedSkills);
    changedPaths.push(path.relative(repoRoot, skillsFilePath));
    changedPaths.push(path.relative(repoRoot, registryFilePath));
  }

  return [...new Set(changedPaths)];
}

function buildFinalSkillItem(existingSkill, manifest) {
  if (manifest.mode === "add") {
    return {
      slug: manifest.slug,
      name: manifest.name,
      description: manifest.description,
      summary: manifest.summary,
      tags: manifest.tags,
      platforms: manifest.platforms,
      installTargets: manifest.installTargets,
      version: manifest.version,
      owner: manifest.owner,
      updatedAt: manifest.updatedAt ?? formatDate(new Date()),
      downloadUrl: `/files/skills/${manifest.slug}.zip`,
      docUrl: `/docs/skills/${manifest.slug}`,
      ...(manifest.repoUrl ? { repoUrl: manifest.repoUrl } : {}),
      ...(manifest.featured !== undefined ? { featured: manifest.featured } : {}),
    };
  }

  if (!existingSkill) {
    fail(`Cannot update missing skill ${manifest.slug}`);
  }

  if (!manifest.updateKinds.has("metadata")) {
    return existingSkill;
  }

  return {
    ...existingSkill,
    ...(manifest.name ? { name: manifest.name } : {}),
    ...(manifest.description ? { description: manifest.description } : {}),
    ...(manifest.summary ? { summary: manifest.summary } : {}),
    ...(manifest.tags ? { tags: manifest.tags } : {}),
    ...(manifest.platforms ? { platforms: manifest.platforms } : {}),
    ...(manifest.installTargets ? { installTargets: manifest.installTargets } : {}),
    ...(manifest.version ? { version: manifest.version } : {}),
    ...(manifest.owner ? { owner: manifest.owner } : {}),
    updatedAt: manifest.updatedAt ?? formatDate(new Date()),
    ...(manifest.repoUrl === null
      ? { repoUrl: undefined }
      : manifest.repoUrl
      ? { repoUrl: manifest.repoUrl }
      : {}),
    ...(manifest.featured !== undefined ? { featured: manifest.featured } : {}),
  };
}

function loadSkillItems(filePath) {
  const source = fs.readFileSync(filePath, "utf8");
  const match = source.match(/export const skills:[\s\S]*?=\s*(\[[\s\S]*?\])\s*as const;/);

  if (!match) {
    fail(`Unable to read skills array from ${filePath}`);
  }

  const items = vm.runInNewContext(match[1], {});
  if (!Array.isArray(items)) {
    fail(`Expected skills array in ${filePath}`);
  }
  return items;
}

function writeSkillsFile(filePath, skills) {
  const lines = [
    "export type SkillItem = {",
    "  readonly slug: string;",
    "  readonly name: string;",
    "  readonly description: string;",
    "  readonly summary: string;",
    "  readonly tags: readonly string[];",
    "  readonly platforms: readonly string[];",
    '  readonly installTargets: readonly ("copilot" | "claude" | "codex")[];',
    "  readonly version: string;",
    "  readonly owner: string;",
    "  readonly updatedAt: string;",
    "  readonly downloadUrl: string;",
    "  readonly docUrl: string;",
    "  readonly repoUrl?: string;",
    "  readonly featured?: boolean;",
    "};",
    "",
    "export const skills: readonly SkillItem[] = [",
    skills.map((item) => formatSkillItem(item)).join(",\n"),
    "] as const;",
    "",
    "export const skillTags: readonly string[] = [",
    '  "全部",',
    "  ...Array.from(new Set(skills.flatMap((skill) => skill.tags))),",
    "] as const;",
    "",
  ];

  fs.writeFileSync(filePath, lines.join("\n"));
}

function formatSkillItem(item) {
  const lines = ["  {"];
  pushStringProperty(lines, "slug", item.slug);
  pushStringProperty(lines, "name", item.name);
  pushStringProperty(lines, "description", item.description);
  pushStringProperty(lines, "summary", item.summary);
  lines.push(`    tags: ${formatStringArray(item.tags)},`);
  lines.push(`    platforms: ${formatStringArray(item.platforms)},`);
  lines.push(`    installTargets: ${formatStringArray(item.installTargets)},`);
  pushStringProperty(lines, "version", item.version);
  pushStringProperty(lines, "owner", item.owner);
  pushStringProperty(lines, "updatedAt", item.updatedAt);
  pushStringProperty(lines, "downloadUrl", item.downloadUrl);
  pushStringProperty(lines, "docUrl", item.docUrl);
  if (item.repoUrl) {
    pushStringProperty(lines, "repoUrl", item.repoUrl);
  }
  if (item.featured !== undefined) {
    lines.push(`    featured: ${item.featured},`);
  }
  lines.push("  }");
  return lines.join("\n");
}

function pushStringProperty(lines, key, value) {
  const rendered = JSON.stringify(value);
  if (String(value).length > 68) {
    lines.push(`    ${key}:`);
    lines.push(`      ${rendered},`);
    return;
  }
  lines.push(`    ${key}: ${rendered},`);
}

function formatStringArray(values) {
  return `[${values.map((value) => JSON.stringify(value)).join(", ")}]`;
}

function writeRegistryFile(filePath, skills) {
  const registry = skills.map((skill) => ({
    slug: skill.slug,
    name: skill.name,
    version: skill.version,
    packageUrl: skill.downloadUrl,
    docUrl: skill.docUrl,
    installTargets: skill.installTargets,
  }));

  fs.writeFileSync(filePath, JSON.stringify(registry, null, 2) + "\n");
}

function writeSkillDoc(filePath, skill, docSections) {
  const sections = docSections.map((section) => {
    const trimmedContent = section.markdown.trim();
    return `## ${section.title}\n\n${trimmedContent}`;
  });

  sections.push(
    "## 下载与来源",
    `- 下载包：[${skill.slug}.zip](${skill.downloadUrl})`,
    "- 终端安装请从 Skill Hub 列表页复制命令",
  );

  if (skill.repoUrl) {
    sections.push(`- 仓库地址：${skill.repoUrl}`);
  }

  const content = [
    "---",
    `title: ${escapeFrontmatterValue(skill.name)}`,
    `description: ${escapeFrontmatterValue(skill.description)}`,
    "---",
    "",
    `# ${skill.name}`,
    "",
    ...sections,
    "",
  ].join("\n");

  fs.writeFileSync(filePath, content);
}

function escapeFrontmatterValue(value) {
  return JSON.stringify(value);
}

function syncSourceDirectory(sourceDir, destinationDir) {
  fs.rmSync(destinationDir, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(destinationDir), { recursive: true });
  const root = path.resolve(sourceDir);

  fs.cpSync(root, destinationDir, {
    recursive: true,
    preserveTimestamps: true,
    filter(sourcePath) {
      if (sourcePath === root) {
        return true;
      }
      return !COPY_EXCLUDES.has(path.basename(sourcePath));
    },
  });
}

function packageSkillZip(repoRoot, slug) {
  const zipPath = path.join(repoRoot, "static/files/skills", `${slug}.zip`);
  const skillsRoot = path.join(repoRoot, "skills_hub");
  fs.mkdirSync(path.dirname(zipPath), { recursive: true });
  fs.rmSync(zipPath, { force: true });

  if (commandExists("zip")) {
    runCommand("zip", ["-rq", zipPath, slug, "-x", ...ZIP_EXCLUDES], { cwd: skillsRoot });
    return;
  }

  if (commandExists("python3")) {
    runCommand(
      "python3",
      [
        "-c",
        [
          "import os",
          "import sys",
          "import zipfile",
          "",
          "root_dir, slug, zip_path = sys.argv[1], sys.argv[2], sys.argv[3]",
          "excludes = {'.DS_Store', '__MACOSX', '__pycache__', 'node_modules', '.git', 'dist', 'build'}",
          "source_dir = os.path.join(root_dir, slug)",
          "with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as archive:",
          "    for current_root, dirs, files in os.walk(source_dir):",
          "        dirs[:] = [name for name in dirs if name not in excludes]",
          "        for file_name in files:",
          "            if file_name in excludes:",
          "                continue",
          "            absolute_path = os.path.join(current_root, file_name)",
          "            relative_path = os.path.relpath(absolute_path, root_dir)",
          "            archive.write(absolute_path, relative_path)",
        ].join("\n"),
        skillsRoot,
        slug,
        zipPath,
      ],
      { cwd: repoRoot },
    );
    return;
  }

  fail("Missing ZIP support. Install zip or python3.");
}

function runValidation(repoRoot, workingBranch, manifestPath) {
  try {
    runCommand("node", ["scripts/validate-skills.mjs"], { cwd: repoRoot });
    runCommand("npm", ["run", "build:dev"], { cwd: repoRoot });
  } catch {
    fail(
      [
        "Skill validation or site build failed. Review the command output above.",
        "If the problem is in your sourceDir or manifest, fix it and rerun on the same branch:",
        buildApplyCommand(manifestPath, { resume: true }),
        "If you prefer to hand-edit the cloned repository directly, continue from that branch with git instead of rerunning the script.",
        `Repository: ${repoRoot}`,
        `Branch: ${workingBranch}`,
      ].join("\n"),
    );
  }
}

function stagePaths(repoRoot, relativePaths) {
  runCommand("git", ["add", "--", ...relativePaths], { cwd: repoRoot });
}

function hasStagedChanges(repoRoot) {
  try {
    runCommand("git", ["diff", "--cached", "--quiet"], { cwd: repoRoot, stdio: "ignore" });
    return false;
  } catch {
    return true;
  }
}

function gitWorkingTreeDirty(repoRoot) {
  const status = runCommandCapture("git", ["status", "--short"], { cwd: repoRoot });
  return status.trim().length > 0;
}

function currentBranchName(repoRoot) {
  const branch = runCommandCapture("git", ["branch", "--show-current"], { cwd: repoRoot });
  return branch.trim() || undefined;
}

function localBranchExists(repoRoot, branchName) {
  const result = runCommandCapture("git", ["branch", "--list", branchName], { cwd: repoRoot });
  return result.trim().length > 0;
}

function branchHasLocalCommits(repoRoot) {
  const count = runCommandCapture(
    "git",
    ["rev-list", "--count", `origin/${DEFAULT_BASE_BRANCH}..HEAD`],
    { cwd: repoRoot },
  );
  return Number(count.trim() || "0") > 0;
}

function ensureDependencies(repoRoot) {
  if (fs.existsSync(path.join(repoRoot, "node_modules"))) {
    return;
  }

  ensureCommand("npm");
  runCommand("npm", ["install"], { cwd: repoRoot });
}

function validateSourceDirectory(sourceDir, slug) {
  if (!sourceDir || !fs.existsSync(sourceDir)) {
    fail(`sourceDir does not exist: ${sourceDir || "<empty>"}`);
  }

  const stat = fs.statSync(sourceDir);
  if (!stat.isDirectory()) {
    fail(`sourceDir must be a directory: ${sourceDir}`);
  }

  const skillPath = path.join(sourceDir, "SKILL.md");
  if (!fs.existsSync(skillPath)) {
    fail(`sourceDir is missing SKILL.md: ${sourceDir}`);
  }

  const frontmatter = parseFrontmatter(skillPath);
  if (frontmatter.name !== slug) {
    fail(`SKILL.md frontmatter name must match slug ${slug}`);
  }

  if (!frontmatter.description) {
    fail(`SKILL.md frontmatter description is required for ${slug}`);
  }
}

function parseFrontmatter(filePath) {
  const source = fs.readFileSync(filePath, "utf8");
  const match = source.match(/^---\n([\s\S]*?)\n---\n?/);

  if (!match) {
    fail(`Missing YAML frontmatter in ${filePath}`);
  }

  const frontmatter = {};
  for (const rawLine of match[1].split("\n")) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }
    const separatorIndex = line.indexOf(":");
    if (separatorIndex === -1) {
      continue;
    }
    const key = line.slice(0, separatorIndex).trim();
    let value = line.slice(separatorIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    frontmatter[key] = value;
  }

  return frontmatter;
}

function readJsonFile(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function normalizeInstallTargets(value) {
  if (!Array.isArray(value) || value.length === 0) {
    fail("installTargets must be a non-empty array when provided");
  }

  const normalized = value.map((item) => String(item).trim()).filter(Boolean);
  for (const target of normalized) {
    if (!DEFAULT_INSTALL_TARGETS.includes(target)) {
      fail(`Unsupported install target: ${target}`);
    }
  }

  return [...new Set(normalized)];
}

function normalizeUpdateKinds(value, mode) {
  if (mode === "add") {
    return new Set(["metadata", "docs", "source", "zip"]);
  }

  if (!Array.isArray(value) || value.length === 0) {
    fail("updateKinds must be a non-empty array for update mode");
  }

  const normalized = new Set(
    value.map((item) => String(item).trim()).filter(Boolean),
  );

  for (const kind of normalized) {
    if (!SUPPORTED_UPDATE_KINDS.has(kind)) {
      fail(`Unsupported updateKind: ${kind}`);
    }
  }

  if (normalized.has("source") || normalized.has("zip")) {
    normalized.add("source");
    normalized.add("zip");
  }

  return normalized;
}

function normalizeDocSections(value) {
  if (value === undefined || value === null || value === "") {
    return [];
  }

  if (!Array.isArray(value)) {
    fail("docSections must be an array");
  }

  return value.map((section, index) => {
    if (!section || typeof section !== "object" || Array.isArray(section)) {
      fail(`docSections[${index}] must be an object`);
    }

    const title = String(section.title ?? "").trim();
    const markdown = String(section.markdown ?? "").trim();

    if (!title || !markdown) {
      fail(`docSections[${index}] requires non-empty title and markdown`);
    }

    return { title, markdown };
  });
}

function normalizeOptionalString(value) {
  if (value === undefined || value === null) {
    return undefined;
  }
  const normalized = String(value).trim();
  return normalized || undefined;
}

function normalizeNullableString(object, key) {
  if (!Object.prototype.hasOwnProperty.call(object, key)) {
    return undefined;
  }

  const value = object[key];
  if (value === null) {
    return null;
  }

  const normalized = normalizeOptionalString(value);
  return normalized ?? undefined;
}

function normalizeOptionalStringList(value) {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }

  if (!Array.isArray(value) || value.length === 0) {
    fail("Expected a non-empty string array");
  }

  const normalized = value.map((item) => String(item).trim()).filter(Boolean);
  if (normalized.length === 0) {
    fail("Expected a non-empty string array");
  }
  return normalized;
}

function normalizeDateString(value) {
  const normalized = normalizeOptionalString(value);
  if (!normalized) {
    return undefined;
  }

  if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
    fail(`updatedAt must use YYYY-MM-DD, received "${normalized}"`);
  }

  return normalized;
}

function resolveOptionalPath(value, baseDir) {
  const normalized = normalizeOptionalString(value);
  if (!normalized) {
    return undefined;
  }
  return path.resolve(baseDir, normalized);
}

function defaultRepoPath() {
  return path.join(os.homedir(), ".skill-hub-contributor", "app-docs");
}

function buildApplyCommand(manifestPath, options = {}) {
  const parts = [
    "node",
    JSON.stringify(path.resolve(process.argv[1])),
    "apply",
    "--manifest",
    JSON.stringify(manifestPath),
  ];

  if (options.resume) {
    parts.push("--resume");
  }

  if (options.push) {
    parts.push("--push");
  }

  if (options.checkOnly) {
    parts.push("--check-only");
  }

  if (options.skipPush) {
    parts.push("--skip-push");
  }

  return parts.join(" ");
}

function pushDraftMergeRequest(repoRoot, workingBranch, commitMessage, manifestPath) {
  try {
    runCommandBuffered(
      "git",
      [
        "push",
        "-u",
        "origin",
        workingBranch,
        "-o",
        "merge_request.create",
        "-o",
        `merge_request.target=${DEFAULT_BASE_BRANCH}`,
        "-o",
        `merge_request.title=${commitMessage}`,
        "-o",
        "merge_request.draft",
      ],
      { cwd: repoRoot },
    );
  } catch (error) {
    const output = extractCommandErrorOutput(error);
    const details = output.trim();
    const looksLikePermissionError = /permission denied|access denied|not allowed to push|not allowed to upload|not allowed to.*project|you are not allowed/i.test(
      details.toLowerCase(),
    );

    fail(
      [
        looksLikePermissionError
          ? "Git push was rejected. The current account can reach the repository but does not have SSH push permission for this project."
          : "git push or draft MR creation failed.",
        "The local branch and commit were kept so you can continue without losing work.",
        `Repository: ${repoRoot}`,
        `Branch: ${workingBranch}`,
        looksLikePermissionError
          ? "This is a permission problem, not a skill content problem. Ask Li Hailong to add your app-docs GitLab SSH push permission, then rerun the same branch."
          : "Check the remote output below, fix the problem, then rerun on the same branch.",
        `Retry: ${buildApplyCommand(manifestPath, { resume: true, push: true })}`,
        details ? `Git says:\n${details}` : "",
      ]
        .filter(Boolean)
        .join("\n"),
    );
  }
}

function runCommand(command, args, options) {
  execFileSync(command, args, {
    cwd: options.cwd,
    stdio: options.stdio ?? "inherit",
  });
}

function runCommandBuffered(command, args, options) {
  try {
    execFileSync(command, args, {
      cwd: options.cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (error) {
    throw {
      ...error,
      stdout: toUtf8(error.stdout),
      stderr: toUtf8(error.stderr),
    };
  }
}

function runCommandCapture(command, args, options) {
  return execFileSync(command, args, {
    cwd: options.cwd,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
}

function commandExists(command) {
  try {
    execFileSync("sh", ["-c", `command -v ${command} >/dev/null 2>&1`], {
      stdio: "ignore",
    });
    return true;
  } catch {
    return false;
  }
}

function extractCommandErrorOutput(error) {
  if (!error || typeof error !== "object") {
    return "";
  }

  return [toUtf8(error.stdout), toUtf8(error.stderr)].filter(Boolean).join("\n");
}

function toUtf8(value) {
  if (!value) {
    return "";
  }
  if (typeof value === "string") {
    return value;
  }
  if (Buffer.isBuffer(value)) {
    return value.toString("utf8");
  }
  return String(value);
}

function ensureCommand(command) {
  if (!commandExists(command)) {
    fail(`Missing required command: ${command}`);
  }
}

function isMissingMetadataField(manifest, field) {
  const value = manifest[field];
  if (Array.isArray(value)) {
    return value.length === 0;
  }
  return !value;
}

function formatDate(date) {
  return date.toISOString().slice(0, 10);
}

function formatTimestamp(date) {
  const parts = [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, "0"),
    String(date.getDate()).padStart(2, "0"),
    String(date.getHours()).padStart(2, "0"),
    String(date.getMinutes()).padStart(2, "0"),
    String(date.getSeconds()).padStart(2, "0"),
  ];
  return parts.join("");
}

function fail(message) {
  throw new Error(message);
}
