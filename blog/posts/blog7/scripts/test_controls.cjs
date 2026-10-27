// Logic test of the exact generated control script, without launching a browser.
// This verifies state/data transitions, not visual layout or actual browser clicks.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'figures/life_expectancy.html'), 'utf8');
const spec = JSON.parse(fs.readFileSync(path.join(root, 'figures/figure_spec.json'), 'utf8'));
const controls = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1];
const elements = new Map();
const chart = {data: structuredClone(spec.data), layout: structuredClone(spec.layout), handlers: {},
    on(name, callback) { this.handlers[name] = callback; }};
elements.set('life-chart', chart);
for (const id of ['gap-mode', 'level-mode', 'country-filter', 'reset-chart', 'chart-status']) {
    elements.set(id, {value: 'all', textContent: '', attributes: {}, handlers: {},
        setAttribute(k, v) { this.attributes[k] = v; },
        addEventListener(k, fn) { this.handlers[k] = fn; }});
}
const Plotly = {
    async update(el, data, layout) {
        data.y.forEach((y, i) => el.data[i].y = y);
        Object.assign(el.layout, layout);
    },
    async restyle(el, data) {
        data.visible.forEach((v, i) => el.data[i].visible = v);
        el.handlers.plotly_restyle?.();
    }
};
const context = vm.createContext({document: {getElementById: id => elements.get(id)}, Plotly});
vm.runInContext(controls, context);
const click = id => elements.get(id).handlers.click();
const visible = () => chart.data.map(t => t.visible !== false && t.visible !== 'legendonly');
(async () => {
    await elements.get('country-filter').handlers.change({target: {value: '4'}});
    assert.deepEqual(visible(), [false, false, false, false, true, false, false]);
    await click('level-mode');
    assert.deepEqual(visible(), [false, false, false, false, true, false, false]);
    chart.data.forEach(t => t.y.forEach((y, j) => assert.equal(y, t.customdata[j][0])));
    assert.equal(elements.get('level-mode').attributes['aria-pressed'], 'true');
    assert.equal(chart.layout['shapes[0].visible'], false);
    await click('gap-mode');
    chart.data.forEach(t => t.y.forEach((y, j) => assert.equal(y, t.customdata[j][2])));
    assert.equal(chart.layout['shapes[0].visible'], true);
    assert.match(elements.get('chart-status').textContent, /1 countries shown/);
    await click('reset-chart');
    assert.ok(visible().every(Boolean));
    assert.equal(elements.get('country-filter').value, 'all');
    assert.equal(elements.get('gap-mode').attributes['aria-pressed'], 'true');
    assert.equal(JSON.stringify(chart.layout['yaxis.range']), JSON.stringify([-2.65, .4]));
    assert.match(elements.get('chart-status').textContent, /7 countries shown/);
    await elements.get('country-filter').handlers.change({target: {value: 'all'}});
    assert.ok(visible().every(Boolean));
    console.log('PASS: select country, preserve selection across measures, exact level/gap data, reference visibility, reset, all-country selection. Browser/visual tests not performed.');
})().catch(error => {console.error(error);process.exitCode = 1;});
