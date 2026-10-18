export default function saveTimeZone() {
    try {
        const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
        if (!timeZone) return;

        const cookie = `time_zone=${encodeURIComponent(timeZone)}`;
        if (document.cookie.split(";").some((value) => value.trim() === cookie)) return;

        const secure = location.protocol === "https:" ? "; Secure" : "";
        document.cookie = `${cookie}; Path=/; Max-Age=31536000; SameSite=Lax${secure}`;
    } catch {
        // Browser time zones and cookies are optional; keep the server fallback.
    }
}
