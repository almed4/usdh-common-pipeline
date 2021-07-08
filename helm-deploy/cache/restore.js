const cache = require("@actions/cache");
const core = require("@actions/core");

const KEY = process.env.GITHUB_REPOSITORY;

console.log(`repo: ${KEY}`);
