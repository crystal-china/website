import htmx from 'htmx.org';
window.htmx = htmx;
import _hyperscript from 'hyperscript.org';
_hyperscript.browserInit();
import tabs from 'missing.css/www/missing-js/tabs.js';

function init () {
    let tabs_div = document.querySelector("#tabs");
    if (tabs_div != null) {
        tabs(document.querySelector("#tabs"));
    }
}

htmx.onLoad(init);
