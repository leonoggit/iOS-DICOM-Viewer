// Quick Start Examples for Python Poetry MCP

// Example 1: Create a simple Python package
async function createSimplePackage() {
  // Create the project
  await mcp.call("poetry_create_project", {
    name: "my-package",
    path: "/Users/username/projects",
    python: "3.11"
  });
  
  // Add common dependencies
  await mcp.call("poetry_add_dependency", {
    projectPath: "/Users/username/projects/my-package",
    packages: ["requests", "click", "pydantic"]
  });
  
  // Add dev dependencies
  await mcp.call("poetry_add_dependency", {
    projectPath: "/Users/username/projects/my-package",
    packages: ["pytest", "black", "mypy", "ruff"],
    dev: true
  });
  
  // Install everything
  await mcp.call("poetry_install", {
    projectPath: "/Users/username/projects/my-package"
  });
}

// Example 2: Set up a data science project
async function createDataScienceProject() {
  // Create project with src layout
  await mcp.call("poetry_create_project", {
    name: "ds-analysis",
    path: "/Users/username/projects",
    python: "3.11",
    src: true
  });
  
  // Add data science packages
  await mcp.call("poetry_add_dependency", {
    projectPath: "/Users/username/projects/ds-analysis",
    packages: [
      "pandas",
      "numpy",
      "matplotlib",
      "seaborn",
      "jupyter",
      "scikit-learn",
      "statsmodels"
    ]
  });
  
  // Run Jupyter
  await mcp.call("poetry_run", {
    projectPath: "/Users/username/projects/ds-analysis",
    command: "jupyter",
    args: ["notebook"]
  });
}

// Example 3: Create a FastAPI web service
async function createFastAPIService() {
  // Create the project
  await mcp.call("poetry_create_project", {
    name: "api-service",
    path: "/Users/username/projects",
    python: "3.11"
  });
  
  // Add FastAPI and related packages
  await mcp.call("poetry_add_dependency", {
    projectPath: "/Users/username/projects/api-service",
    packages: [
      "fastapi",
      "uvicorn[standard]",
      "pydantic",
      "httpx",
      "sqlalchemy",
      "alembic"
    ]
  });
  
  // Add dev dependencies
  await mcp.call("poetry_add_dependency", {
    projectPath: "/Users/username/projects/api-service",
    packages: ["pytest", "pytest-asyncio", "pytest-cov"],
    dev: true
  });
  
  // Export requirements for Docker
  await mcp.call("poetry_export_requirements", {
    projectPath: "/Users/username/projects/api-service",
    output: "requirements.txt",
    withoutHashes: true
  });
}

// Example 4: Update all dependencies safely
async function updateDependenciesSafely() {
  const projectPath = "/path/to/existing/project";
  
  // First, check what would be updated
  const dryRun = await mcp.call("poetry_update_dependency", {
    projectPath,
    dry: true
  });
  
  console.log("Updates available:", dryRun);
  
  // Check for conflicts
  await mcp.call("poetry_check_conflicts", {
    projectPath
  });
  
  // If everything looks good, update
  await mcp.call("poetry_update_dependency", {
    projectPath
  });
  
  // Verify the lock file
  await mcp.call("poetry_lock", {
    projectPath,
    check: true
  });
}

// Example 5: Publish a package to PyPI
async function publishPackage() {
  const projectPath = "/path/to/my/package";
  
  // Run tests first
  await mcp.call("poetry_run", {
    projectPath,
    command: "pytest",
    args: ["-v", "--cov"]
  });
  
  // Check the package
  await mcp.call("poetry_check_conflicts", {
    projectPath
  });
  
  // Build and publish
  await mcp.call("poetry_publish", {
    projectPath,
    token: process.env.PYPI_API_TOKEN,
    build: true
  });
}