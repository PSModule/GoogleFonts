# Font Data Updater

This directory contains scripts for automating the maintenance of the GoogleFonts module.

## Update-FontsData.ps1

This script automatically updates the `src/FontsData.json` file with the latest font metadata from Google Fonts API.

### Features

- **Automatic Updates**: Runs daily via GitHub Actions to fetch the latest font data
- **PR Supersedence**: Automatically closes older update pull requests when a new update is available
- **Clean Repository**: Ensures only the most recent update PR remains open

### How It Works

1. **Scheduled Execution**: The script runs daily at midnight UTC via the `Update-FontsData` workflow
2. **Data Fetching**: Retrieves the latest font metadata from Google Fonts API
3. **Change Detection**: Compares new data with existing `FontsData.json`
4. **PR Creation**: If changes are detected:
   - Creates a new branch named `auto-update-YYYYMMDD-HHmmss`
   - Commits the updated `FontsData.json`
   - Opens a pull request with title `Auto-Update YYYYMMDD-HHmmss`
5. **PR Supersedence**: Before creating a new PR, the script:
   - Searches for existing open PRs with titles matching `Auto-Update*`
   - Closes each superseded PR with a comment explaining the supersedence
   - Ensures only the latest update PR remains open

### PR Lifecycle Management

The font data updater implements PR supersedence similar to Dependabot:

#### When a New Update PR is Created

- The script checks for existing open `Auto-Update*` PRs
- Each existing PR receives a comment:
  ```
  This PR has been superseded by a newer update and will be closed automatically.
  
  The font data has been updated in a more recent PR. Please refer to the latest Auto-Update PR for the most current changes.
  ```
- All superseded PRs are automatically closed

#### When an Update PR is Merged

- The `Cleanup-FontsData-PRs` workflow is triggered
- Any remaining open `Auto-Update*` PRs are detected
- Each remaining PR receives a comment referencing the merged PR
- All obsolete PRs are automatically closed

### Workflows

#### Update-FontsData.yml

Handles the scheduled updates and PR creation:
- **Trigger**: Daily at midnight UTC, or manual via `workflow_dispatch`
- **Authentication**: Uses GitHub App credentials for API access
- **Permissions**: Requires secrets:
  - `GOOGLE_DEVELOPER_API_KEY`: For accessing Google Fonts API
  - `GOOGLEFONTS_UPDATER_BOT_CLIENT_ID`: GitHub App client ID
  - `GOOGLEFONTS_UPDATER_BOT_PRIVATE_KEY`: GitHub App private key

#### Cleanup-FontsData-PRs.yml

Handles cleanup after PR merges:
- **Trigger**: When a PR modifying `src/FontsData.json` is merged to main
- **Action**: Closes any remaining open `Auto-Update*` PRs that are now obsolete
- **Authentication**: Uses the same GitHub App credentials

### Manual Execution

You can manually trigger an update using the GitHub Actions UI:

1. Go to the **Actions** tab in the repository
2. Select the **Update-FontsData** workflow
3. Click **Run workflow**
4. Select the branch and click **Run workflow**

### Configuration

The supersedence behavior is built into the script and requires no additional configuration. The message posted when closing superseded PRs is defined in the script and can be customized by modifying:

- `scripts/Update-FontsData.ps1` (lines 135-138) - Message for PRs closed when creating a new update
- `.github/workflows/Cleanup-FontsData-PRs.yml` (lines 30-33) - Message for PRs closed after a merge

### Development

To test changes to the update script:

1. Create a feature branch
2. Modify `scripts/Update-FontsData.ps1`
3. Push the branch
4. Manually trigger the workflow on your feature branch
5. The script will detect it's running on a feature branch and update the existing branch instead of creating a new PR

### Troubleshooting

- **No updates available**: If the Google Fonts API returns the same data, no PR will be created
- **Authentication errors**: Ensure the GitHub App credentials are correctly configured
- **API rate limits**: The Google Fonts API key must have sufficient quota for daily requests
