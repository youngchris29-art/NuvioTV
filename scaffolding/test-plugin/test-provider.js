// Test scraper for the tvOS plugin runtime. Exercises the real plugin surface:
// async getStreams, the fetch bridge (network call from inside QuickJS), and the
// result-parsing path. Fully self-contained: streams test.mp4 from the same local
// HTTP server that serves this repo (origin derived from SCRAPER_ID, which the
// runtime sets to "<manifestUrl>:<scraperId>").
function repoOrigin() {
  var id = String(globalThis.SCRAPER_ID || "");
  var m = id.match(/^(https?:\/\/[^\/]+)/);
  return m ? m[1] : "";
}

async function getStreams(tmdbId, mediaType, season, episode) {
  var origin = repoOrigin();
  var results = [];

  // 1. Static result — proves basic execution + result parsing + playback.
  results.push({
    name: "Test Provider",
    title: "Local test clip (static result) [" + mediaType + " " + tmdbId + "]",
    url: origin + "/test.mp4",
    quality: "720p",
    size: "12 MB",
    provider: "test"
  });

  // 2. Result gated on a real fetch() — proves the network bridge works.
  try {
    var res = await fetch(origin + "/manifest.json");
    var body = await res.json();
    results.push({
      name: "Test Provider",
      title: "Local test clip (fetch OK: repo '" + body.name + "')",
      url: origin + "/test.mp4",
      quality: "720p",
      provider: "test"
    });
  } catch (e) {
    results.push({
      name: "Test Provider",
      title: "FETCH FAILED: " + (e && e.message ? e.message : e),
      url: origin + "/test.mp4",
      quality: "SD",
      provider: "test"
    });
  }

  if (mediaType === "tv") {
    results.push({
      name: "Test Provider",
      title: "Episode marker S" + season + "E" + episode,
      url: origin + "/test.mp4",
      quality: "720p",
      provider: "test"
    });
  }

  return results;
}

module.exports = { getStreams: getStreams };
