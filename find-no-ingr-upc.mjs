// Try various UPCs to find one OBF has brand+name but missing ingredients
const upcs = [
  '3614270040801', // some random
  '3600541269439',
  '8410104872618',
  '3145891316308',
  '0762141500106',
  '3274872400290',
  '0381519028892', // Olay
  '0381519151415',
  '0381519151392',
  '0381519122996',
  '0019100040305', // Vaseline
  '0044100009617', // Aveeno
  '0381370044376', // Olay
];
for (const upc of upcs) {
  const r = await fetch(`https://world.openbeautyfacts.org/api/v2/product/${upc}.json`, {
    headers: { 'User-Agent': 'Skintel/1.0' },
  });
  const d = await r.json();
  if (d.status === 1) {
    const p = d.product;
    const hasIngr = (p.ingredients_text || '').trim().length > 0;
    console.log(upc, '|', p.brands || '-', '|', (p.product_name || '-').slice(0, 40), '| ingr:', hasIngr ? 'YES' : 'NO');
  } else {
    console.log(upc, '| NOT FOUND');
  }
}
