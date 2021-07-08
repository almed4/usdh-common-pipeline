const cache = require("@actions/cache");
const core = require("@actions/core");

const KEY = process.env.GITHUB_REPOSITORY;

async function run() {
    try {
        try {
            core.info('Restoring Cache\n------------------------------------------------------------------------------------------\n');
            core.info(`cache: ${KEY}`)

            const cacheKey = await cache.restoreCache(['/tmp/.buildx-cache'], KEY);
            if (!cacheKey) {
                core.info(`Cache not found for key: ${KEY}. Can't restore.`)
                return;
            }

            core.saveState('CACHE_RESULT', cacheKey);

            core.info(`Cache restore from key: ${KEY}`)
        } catch (error) {
            if (error.name === cache.ValidationError.name) {
                throw error;
            } else {
                core.info(`[waring]${error.message}`);
                core.setOutput('cache-hit', false.toString())
            }
        }
    } catch (error) {
        core.setFailed(error.message);
    }
}

run().then(process.exit(0)).catch(process.exit(1));