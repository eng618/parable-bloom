# Bitwarden Secrets Manager Setup for Parable Bloom

## ✅ Completed Setup

### Bitwarden Project Created

- **Project Name**: `parable-bloom`
- **Project ID**: `7864e88f-517c-4da9-a114-b3bc0032bca0`
- **Secrets Created**:
  - `FIREBASE_WEB_API_KEY`: Web API key for Firebase
  - `FIREBASE_PROJECT_ID`: Firebase project identifier

### CI/CD Integration

- Updated `.github/workflows/ci.yml` to retrieve secrets automatically
- Uses official `bitwarden/sm-action@v2` GitHub Action
- Secrets injected as environment variables during builds

## 🔧 Manual Setup Required

### 1. Create Service Account Access Token

Since Bitwarden Secrets Manager requires a service account for CI/CD access, you need to create this through the Bitwarden web interface:

1. Go to [https://vault.bitwarden.com](https://vault.bitwarden.com)
2. Navigate to **Organization Settings** → **Secrets Manager**
3. Click **Service Accounts** → **New Service Account**
4. Name it `parable-bloom-ci`
5. Grant access to the `parable-bloom` project
6. Copy the generated **Access Token**

### 2. Add Access Token to GitHub Secrets

1. Go to your GitHub repository: **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `BWS_ACCESS_TOKEN`
4. Value: Paste the service account access token from step 1
5. Click **Add secret**

### 3. Verify Setup

Once you've completed steps 1-2, the CI workflow will automatically:

- Retrieve Firebase secrets from Bitwarden
- Make them available as environment variables
- Use them in Flutter builds

## 📋 Next Steps

### Phase 3: Repository Implementation

1. Create Firebase repository classes
2. Implement cloud sync logic
3. Add offline-first data management
4. Test end-to-end sync functionality

### Phase 4: Enhanced CI/CD

1. Add Firebase deployment workflows
2. Configure app store build secrets
3. Set up automated releases
4. Add Firebase hosting deployment

## 🔍 Troubleshooting

### CI Fails with Authentication Error

- Verify the `BWS_ACCESS_TOKEN` secret is correctly set in GitHub
- Ensure the service account has access to the `parable-bloom` project
- Check that the project ID in the workflow matches: `7864e88f-517c-4da9-a114-b3bc0032bca0`

### Secrets Not Available in Build

- Confirm the `bitwarden/sm-action@v2` syntax in the workflow
- Check that secrets are properly mapped in the `secrets` parameter
- Verify secret names match between Bitwarden and the workflow
- Ensure the service account has access to the specified project

## 🔐 Security Notes

- **Access Token Security**: Never commit access tokens to version control
- **Service Account Scope**: Limit service account access to only required projects
- **Secret Rotation**: Regularly rotate access tokens and API keys
- **Environment Separation**: Consider separate projects/secrets for staging vs production

## 📚 Resources

- [Bitwarden Secrets Manager Documentation](https://bitwarden.com/help/secrets-manager/)
- [GitHub Actions Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Firebase Flutter Documentation](https://firebase.google.com/docs/flutter/setup)

---

**Status**: 🔄 **Awaiting Service Account Setup** - Complete steps 1-2 above, then CI will work automatically.
