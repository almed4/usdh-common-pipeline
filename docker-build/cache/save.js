const cache = require("@actions/cache");
const core = require("@actions/core");

const KEY = process.env.GITHUB_REPOSITORY;

async function run() {
    try {
        core.info('\nSaving Cache\n------------------------------------------------------------------------------------------\n');

        const state = core.getState('CACHE_RESULT')

        if (state && state.localeCompare(KEY, undefined, {sensitivity: 'accent'}) === 0) {
            core.info(`Cache hit occurred on the primary key ${KEY}, not saving cache.`);
            return;
        }
        core.info(`No cache hit occurred on the primary key ${KEY}, saving cache...`);

        try {
            await cache.saveCache(['/tmp/.buildx-cache'], KEY)
            core.info(`Cache saved with key: ${KEY}`);
        } catch (error) {
            if (error.name === cache.ValidationError.name) {
                throw error;
            } else if (error.name === cache.ReserveCacheError.name) {
                core.info(error.message);
            } else {
                core.info(`[waring]${error.message}`);
            }
        }
    } catch (error) {
        core.info(`[waring]${error.message}`);
    }
}

run();
