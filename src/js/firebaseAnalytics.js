import { initializeApp } from "firebase/app";
import { getAnalytics, logEvent } from "firebase/analytics";

const firebaseConfig = JSON.parse(
    document.getElementById("app-config")?.textContent ?? "{}",
).firebaseConfig;
const analytics =
    firebaseConfig?.apiKey == null
        ? null
        : getAnalytics(initializeApp(firebaseConfig));

function trackPageView(root) {
    if (analytics == null) {
        return;
    }

    const element = root.matches("#page-analytics")
        ? root
        : root.querySelector("#page-analytics");

    if (element == null) {
        return;
    }

    logEvent(analytics, "page_view", {
        page_path: element.dataset.pagePath,
        page_title: element.dataset.pageTitle,
    });
}

export default trackPageView;
