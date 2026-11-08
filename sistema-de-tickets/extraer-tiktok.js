// Se ejecuta en una pestaña de TikTok Seller Center (seller-us.tiktok.com) con la sesión iniciada.
// Devuelve el catálogo compacto como texto JSON para pegarlo en sincronizar.html.
(async () => {
  const BASE = '/api/v1/product/local/products/list?locale=en&language=en&aid=4068&app_name=i18n_ecom_shop&device_platform=web&profile=1&tab_id=1&page_size=100&sku_number=500&is_need_target_stock=true&same_product_page_size=3&product_sort_fields=3&product_sort_types=0&page_number=';
  let all = [], page = 1, total = 1;
  while (all.length < total && page < 20) {
    const j = await (await fetch(BASE + page, { headers: { 'X-Tt-Oec-Region': 'US' } })).json();
    if (j.code !== 0) throw new Error('TikTok respondió: ' + j.message);
    total = j.data.total_product_count; all = all.concat(j.data.products || []); page++;
    if (!(j.data.products || []).length) break;
  }
  const isShoe = p => (p.categories || []).some(c => /shoe|footwear|sandal|sneaker|flat|espadrille|heel|wedge|trainer/i.test(c.name));
  const tipoDe = p => (p.categories || []).some(c => /sneaker|trainer|walking/i.test(c.name)) ? 'Tenis' : 'Sandalia';
  const alturaDe = t => { const m = String(t).match(/(\d+(?:[.,]\d+)?)\s*cm/i); if (m) return m[1].replace(',', '.') + ' cm'; return /\bflats?\b/i.test(t) ? 'Flat' : ''; };
  const modeloDe = t => {
    let s = String(t).split(/\s\/|\/|\s[-–]|[-–]\s|:|,/)[0].trim().replace(/\s+/g, ' ');
    s = s.replace(/[-\s]*colombian.*$/i, '').trim() || s;
    if (s.split(' ').length > 3) s = s.split(' ')[0];
    return s.toLowerCase().replace(/(^|\s)\S/g, x => x.toUpperCase());
  };
  const out = [];
  for (const p of all) {
    if (p.product_status_view?.product_main_status !== 1 || !isShoe(p)) continue;
    const props = p.sale_properties || [];
    const colorProp = props.find(x => /color/i.test(x.name));
    const seen = {};
    const colors = colorProp ? colorProp.values.map(v => { let n = v.name.trim() || 'Único'; seen[n] = (seen[n] || 0) + 1; if (seen[n] > 1) n += ' ' + seen[n]; return [n, (v.image?.uri || p.image?.uri || ''), String(v.id)]; }) : [['Único', (p.image?.uri || ''), '']];
    const cIdx = Object.fromEntries(colors.map((c, i) => [c[2], i]));
    const altP = alturaDe(p.product_name);
    const skus = (p.skus || []).map(s => {
      const g = re => (s.properties || []).find(x => re.test(x.name))?.value_name?.trim() || '';
      const stock = (s.quantities || []).reduce((a, q) => a + (q.available_quantity || 0), 0);
      const alt = g(/altura|height/i);
      const cv = (s.properties || []).find(x => /color/i.test(x.name));
      return [s.id, colorProp && cv ? (cIdx[String(cv.value_id)] ?? 0) : 0, g(/talla|size/i), alt ? alturaDe(alt) || alt : altP, stock];
    });
    out.push([p.product_id, modeloDe(p.product_name), p.product_name.slice(0, 90), tipoDe(p), altP, colors.map(c => [c[0], c[1]]), skus]);
  }
  return JSON.stringify({ v: 1, fecha: new Date().toISOString(), p: out });
})();
