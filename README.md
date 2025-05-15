# LiteLLM image with custom patches for cyverse

This version is based on v1.67.4-stable litellm

### HOWTO

1. Clone this repo next to litellm:
    - `cd /opt/src`
    - `git clone https://github.com/cyverse/litellm-docker`
    - `git clone https://github.com/berriai/litellm`

2. Copy and edit the .env_example
    - `cd /opt/src/litellm-docker; cp .env_example .env`

3. Freshen/update litellm tags
    - `cd /opt/src/litellm`
    - `git fetch --tags -u upstream` or `git --tags fetch -u origin`

4. Might need to pull the patch branches
    - `cd /opt/src/litellm`
    - `git fetch origin` or `git fetch upstream`
    - `git checkout --track origin/litellm_team_member_delete_cascade` or use upstream if from your other remote source
    - `git checkout --track origin/litellm_team_member_update_fix`
    - `git log` and double check the main branch this forked from is what you checkout to build from

5. Identify latest version of litellm you want to use
    - `git ls-remote --tags https://github.com/BerriAI/litellm.git | grep -e 'v1\.6[7-9]'`

6. Edit generate-patch.sh
    - update MAIN_TAG to version you want to create (v1.67.4-stable)
    - update `branches` array if adding or removing additional branches
    - Build patch `cd /opt/src/litellm-docker; ./generate-patch.sh` -> v1.67.4-stable-20250515-litellm.patch

7. Update Dockerfile if needed:
    - Make sure `PATCH_VERSION` var matches the patch generated

8. Build docker image to test
    - `make build`

9. Run local tests
    - `cd /opt/src/litellm-docker; docker compose up`
    - `./run-tests.sh`
    - Ctrl-c & `docker compose down -v`
    - `make delete-db` to cleanup postgresql data

10. Tag and publish image to harbor
    - `make harbor`