'use strict';

// /v1/app/version — opportunistic update check.
//
// Returns the latest released version per platform plus a release-notes URL.
// Operators configure this via env vars; defaults match the version baked
// into pubspec.yaml at deploy time.  The endpoint is unauthenticated and
// cached aggressively client-side — the app stays fully functional offline
// when this can't be reached.

const DEFAULT_VERSION = process.env.APP_LATEST_VERSION || '1.0.0';
const RELEASE_NOTES_URL = process.env.APP_RELEASE_NOTES_URL ||
  'https://vetviona.koshkikode.com/changelog';
const DOWNLOAD_URL = process.env.APP_DOWNLOAD_URL ||
  'https://vetviona.koshkikode.com/get';
const MIN_SUPPORTED_VERSION = process.env.APP_MIN_SUPPORTED_VERSION || '1.0.0';

function _perPlatform() {
  return {
    android: {
      latest: process.env.APP_LATEST_ANDROID || DEFAULT_VERSION,
      minSupported: process.env.APP_MIN_ANDROID || MIN_SUPPORTED_VERSION,
      downloadUrl: process.env.APP_DOWNLOAD_ANDROID || DOWNLOAD_URL,
    },
    ios: {
      latest: process.env.APP_LATEST_IOS || DEFAULT_VERSION,
      minSupported: process.env.APP_MIN_IOS || MIN_SUPPORTED_VERSION,
      downloadUrl: process.env.APP_DOWNLOAD_IOS || DOWNLOAD_URL,
    },
    windows: {
      latest: process.env.APP_LATEST_WINDOWS || DEFAULT_VERSION,
      minSupported: process.env.APP_MIN_WINDOWS || MIN_SUPPORTED_VERSION,
      downloadUrl: process.env.APP_DOWNLOAD_WINDOWS || DOWNLOAD_URL,
    },
    macos: {
      latest: process.env.APP_LATEST_MACOS || DEFAULT_VERSION,
      minSupported: process.env.APP_MIN_MACOS || MIN_SUPPORTED_VERSION,
      downloadUrl: process.env.APP_DOWNLOAD_MACOS || DOWNLOAD_URL,
    },
    linux: {
      latest: process.env.APP_LATEST_LINUX || DEFAULT_VERSION,
      minSupported: process.env.APP_MIN_LINUX || MIN_SUPPORTED_VERSION,
      downloadUrl: process.env.APP_DOWNLOAD_LINUX || DOWNLOAD_URL,
    },
  };
}

function build() {
  return {
    ok: true,
    releaseNotesUrl: RELEASE_NOTES_URL,
    serverTime: new Date().toISOString(),
    platforms: _perPlatform(),
  };
}

module.exports = { build };
