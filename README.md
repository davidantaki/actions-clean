# Clean

A Github Action to clean the runner workspace and to cleanup and containers especially if you are running many containers/servcies within an action.

If you are using a self-hosted runner, it is **highly** recommended you set this action to run unconditionally as your
last step.

## Usage

```yaml
# ...
steps:
  - uses: actions/checkout@v2.3.0
# - step 2
# - step 3
# - ...
  - name: Cleanup Github Actions Workspace
    uses: davidantaki/actions-clean@v2.0.0
    env:
      # If true, will remove all workspace contents
      CLEAN_WORKSPACE: true
      # Comma separated list of strings of container IDs not to remove
      PROECTED_CONTAINER_SERVICE_IDS: '[]'
    if: ${{ always() }}
```
