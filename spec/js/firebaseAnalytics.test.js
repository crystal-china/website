import { expect, mock, test } from "bun:test";

test("tracks the current browser path after navigation instead of the server request path", async () => {
    const originalDocument = globalThis.document;
    const originalWindow = globalThis.window;
    const logEvent = mock(() => {});

    mock.module("firebase/app", () => ({ initializeApp: () => ({}) }));
    mock.module("firebase/analytics", () => ({ getAnalytics: () => ({}), logEvent }));

    try {
        globalThis.document = {
            getElementById: () => ({ textContent: JSON.stringify({ firebaseConfig: { apiKey: "test" } }) }),
        };
        globalThis.window = { location: { pathname: "/forum/123" } };

        const { default: trackPageView } = await import("../../src/js/firebaseAnalytics.js");
        const marker = {
            matches: () => true,
            dataset: { pagePath: "/forum", pageTitle: "Saved topic" },
        };

        trackPageView(marker);
        expect(logEvent.mock.calls[0][2]).toEqual({ page_path: "/forum/123", page_title: "Saved topic" });

        window.location.pathname = "/forum/456";
        trackPageView({ matches: () => false, querySelector: () => marker });
        expect(logEvent.mock.calls[1][2].page_path).toBe("/forum/456");

        trackPageView({ matches: () => false, querySelector: () => null });
        expect(logEvent).toHaveBeenCalledTimes(2);
    } finally {
        globalThis.document = originalDocument;
        globalThis.window = originalWindow;
    }
});
