const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(__dirname+'/preview.html','utf8');const source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
class Element{constructor(){this.style={};this.attrs={};this.children=[];this.dataset={};this.checked=true;this.clientWidth=800;this.innerHTML=''}setAttribute(k,v){this.attrs[k]=String(v)}append(x){this.children.push(x)}}
const elements=new Map();const get=id=>{if(!elements.has(id))elements.set(id,new Element());return elements.get(id)};const media={matches:false,addEventListener(){}};
const sandbox={document:{hidden:false,getElementById:get,createElement:()=>new Element(),querySelectorAll:()=>get('actions').children,addEventListener(){}},matchMedia:()=>media,requestAnimationFrame(){},console};vm.createContext(sandbox);vm.runInContext(source,sandbox);
const run=s=>vm.runInContext(s,sandbox);run('frame(0);frame(100)');assert.notEqual(get('leftLeg').attrs.transform,get('rightLeg').attrs.transform);assert.equal(get('actions').children.length,5);
const svgBase=html.match(/<svg[^>]*>([\s\S]*?)<\/svg>/)[1];let panels=[];
for(const [i,action] of ['idle','walk','wave','scan','celebrate'].entries()){
 get('actions').children.find(x=>x.dataset.action===action).onclick();run('t=.19;draw()');
 let svg=svgBase.replace(/<path id="([^"]+)"([^>]*?)\/>/g,(_,id,attrs)=>{
  attrs=attrs.replace(/ style="[^"]*"/g,'');const el=get(id);return `<path ${attrs} transform="${el.attrs.transform||''}"${el.style.display==='none'?' visibility="hidden"':''}/>`;
 }).replace('<g id="bodyRig">',`<g transform="${get('bodyRig').attrs.transform}">`).replace('<g id="sparkles" fill="none" stroke="#BB8B3D" stroke-width="2"></g>',`<g fill="none" stroke="#BB8B3D" stroke-width="2">${get('sparkles').innerHTML}</g>`);
 panels.push(`<g transform="translate(${i*320} 24)">${svg}<text x="160" y="412" text-anchor="middle" font-size="18" fill="#482631">${action}</text></g>`);
}
run('playing=false');const before=run('t');run('frame(500);frame(700)');assert.equal(run('t'),before);
media.matches=true;run('draw()');const still=get('bodyRig').attrs.transform;run('t=50;draw()');assert.equal(get('bodyRig').attrs.transform,still);
fs.writeFileSync('/workspace/scratch/db02211474e3/mascot-states.svg',`<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="470" viewBox="0 0 1600 470"><rect width="1600" height="470" fill="#F4EDE0"/>${panels.join('')}</svg>`);
console.log('PASS: 5 action controls, walking articulation, pause, reduced-motion pose. DOM shim; not a browser rendering test.');
