const stage = document.getElementById("stage");
const back = document.getElementById("back");
const surface = document.getElementById("gl");
const front = document.getElementById("fx");
const giver = document.getElementById("giver");
const giverTitle = document.getElementById("giver-title");
const giverGrid = document.getElementById("giver-grid");
const giverClose = document.getElementById("giver-close");
const bg = back.getContext("2d");
const fg = front.getContext("2d");

const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const mix = (a, b, t) => a + (b - a) * t;
const smooth = (a, b, v) => { const x = clamp((v - a) / (b - a)); return x * x * (3 - 2 * x); };
const out = (t) => 1 - Math.pow(1 - clamp(t), 4);
const TAU = Math.PI * 2;
const BASE = 2.6;
const BURN_START = 0.70;
const BURN_END = 2.12;

let seed = 48017;
function random() { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; }
const hash = (x, y) => { let n = Math.imul(x, 374761393) + Math.imul(y, 668265263); n = Math.imul(n ^ (n >>> 13), 1274126177); return ((n ^ (n >>> 16)) >>> 0) / 4294967295; };
function noise(x, y) { const i = Math.floor(x), j = Math.floor(y); let a = x - i, b = y - j; a = a * a * (3 - 2 * a); b = b * b * (3 - 2 * b); return mix(mix(hash(i, j), hash(i + 1, j), a), mix(hash(i, j + 1), hash(i + 1, j + 1), a), b); }
function fbm(x, y) { return 0.56 * noise(x, y) + 0.28 * noise(x * 2.03 + 17, y * 2.03 + 3) + 0.16 * noise(x * 4.13 + 7, y * 4.13 + 9); }

let burnNormalization = 1;
function burnField(x, y) {
    const inset = Math.min(1 - Math.abs(x * 2 - 1), 1 - Math.abs(y * 2 - 1));
    return clamp((0.10 + 0.81 * inset + (fbm(x * 8 + 4, y * 10 + 2) - 0.5) * 0.22) * burnNormalization);
}

const gl = surface.getContext("webgl", { alpha: true, premultipliedAlpha: true, antialias: false, depth: false });
const FS = `
precision highp float;
uniform vec2 uResolution,uSize,uCenter,uCardSize;
uniform vec3 uAxisX,uAxisY,uNormal;
uniform float uFocal,uProgress,uTime,uOpacity;
uniform sampler2D uCard,uBurn;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float f=.56*noise(p);p=p*2.03+vec2(5.1,3.4);f+=.28*noise(p);p=p*2.01+vec2(7.1,9.2);return f+.16*noise(p);}
float windowMask(vec2 uv,float spread){return smoothstep(-spread,0.0,uv.x)*(1.0-smoothstep(1.0,1.0+spread,uv.x))*smoothstep(-spread,0.0,uv.y)*(1.0-smoothstep(1.0,1.0+spread,uv.y));}
void main(){
  vec2 screen=vec2(gl_FragCoord.x/uResolution.x,1.0-gl_FragCoord.y/uResolution.y)*uSize;
  vec3 ray=vec3(screen-uCenter,-uFocal);
  float den=dot(ray,uNormal);
  float hit=-uFocal*uNormal.z/min(den,-.0001);
  vec3 at=vec3(0.0,0.0,uFocal)+ray*hit;
  vec2 uv=vec2(dot(at,uAxisX),dot(at,uAxisY))/uCardSize+.5;
  vec2 suv=clamp(uv,0.0,1.0);
  float outside=length((uv-suv)*vec2(1.0,1.3));
  float field=texture2D(uBurn,suv).r-outside*.65;
  float edge=field-uProgress;
  float bounds=windowMask(uv,.006);
  float alive=smoothstep(-.003,.009,edge)*bounds;
  float active=smoothstep(.012,.07,uProgress)*(1.0-smoothstep(.91,1.0,uProgress));
  vec3 ink=texture2D(uCard,suv).rgb;
  float charred=(1.0-smoothstep(.004,.062,edge))*active;
  ink=mix(ink,vec3(.018,.028,.045),charred*.98);
  float sweep=exp(-pow((uv.x+.38*uv.y-(-.55+uTime*2.8))/.075,2.0));
  ink+=vec3(.85,.55,.18)*sweep*(1.0-smoothstep(.55,.72,uTime));
  float glide=fract(uTime*0.18);
  float glint=exp(-pow((uv.x+.28*uv.y-(-.45+glide*1.9))/.12,2.0));
  ink+=vec3(.8,.58,.24)*glint*0.22*smoothstep(.6,.95,uTime)*(1.0-smoothstep(.02,.18,uProgress));
  float grain=noise(uv*vec2(530.0,810.0));
  float hot=exp(-abs(edge)*155.0)*bounds*active;
  float corona=exp(-abs(edge)*23.0)*windowMask(uv,.13)*active;
  float n=fbm(vec2(uv.x*9.0,uv.y*8.0+uTime*4.0));
  vec2 advected=uv+vec2((n-.5)*.08,.035+.13*n);
  vec2 advsafe=clamp(advected,0.0,1.0);
  float fireField=texture2D(uBurn,advsafe).r-length(advected-advsafe)*.8;
  float tongues=exp(-abs(fireField-uProgress)*19.0)*smoothstep(.28,.76,fbm(vec2(uv.x*25.0+n*3.0,uv.y*15.0+uTime*8.0)));
  tongues*=windowMask(uv,.16)*active*(1.0-alive*.93);
  float haze=fbm(vec2(uv.x*5.0,uv.y*5.0+uTime*.8));
  float mist=exp(-abs(fireField-uProgress)*6.0)*smoothstep(.43,.73,haze)*windowMask(uv,.23)*active*(1.0-alive)*.13;
  vec3 col=ink*alive;
  col+=vec3(.85,.28,.04)*corona*.9;
  col+=mix(vec3(.75,.18,.02),vec3(1.0,.72,.22),tongues)*tongues*1.5;
  col+=vec3(1.0,.86,.45)*hot*(1.6+grain*.7);
  col+=vec3(.35,.22,.12)*mist;
  float alpha=max(alive,clamp(max(col.r,max(col.g,col.b)),0.0,1.0));
  gl_FragColor=vec4(min(col,vec3(alpha)),alpha)*uOpacity;
}`;

let program = null;
const locations = {};
const U = (n) => locations[n] || (locations[n] = gl && gl.getUniformLocation(program, n));
let width = 1280, height = 720, dpr = 1, elapsed = 0, last = 0, playing = false, raf = 0;
let mode = "hold"; // hold | burn | drop
let pieces = [];
let impact = [];

function compile(type, source) {
    const sh = gl.createShader(type);
    gl.shaderSource(sh, source);
    gl.compileShader(sh);
    if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) return null;
    return sh;
}

function makeMask() {
    const mask = document.createElement("canvas");
    mask.width = 256;
    mask.height = 384;
    const mg = mask.getContext("2d");
    const pixels = mg.createImageData(mask.width, mask.height);
    let peak = 0;
    const values = new Float32Array(mask.width * mask.height);
    burnNormalization = 1;
    for (let y = 0; y < mask.height; y++) {
        for (let x = 0; x < mask.width; x++) {
            const index = y * mask.width + x;
            const value = burnField(x / (mask.width - 1), y / (mask.height - 1));
            values[index] = value;
            peak = Math.max(peak, value);
        }
    }
    burnNormalization = 0.99 / peak;
    for (let index = 0; index < values.length; index++) {
        const k = index * 4;
        const v = Math.round(clamp(values[index] * burnNormalization) * 255);
        pixels.data[k] = pixels.data[k + 1] = pixels.data[k + 2] = v;
        pixels.data[k + 3] = 255;
    }
    mg.putImageData(pixels, 0, 0);
    pieces = Array.from({ length: 280 }, () => {
        const x = random() * 0.98 + 0.01;
        const y = random() * 0.98 + 0.01;
        return { x, y, birth: mix(BURN_START, BURN_END, burnField(x, y)), life: 0.22 + random() * 0.36, speed: 32 + random() * 100, phase: random() * TAU, size: 0.45 + random() * 1.2, ash: random() < 0.18 };
    });
    impact = Array.from({ length: 72 }, () => ({ angle: random() * TAU, speed: 60 + random() * 220, life: 0.21 + random() * 0.27, size: 0.4 + random() * 1.3, phase: random() * TAU }));
    return mask;
}

function upload(image, unit, name) {
    const t = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0 + unit);
    gl.bindTexture(gl.TEXTURE_2D, t);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
    gl.uniform1i(U(name), unit);
}

function initGl() {
    if (!gl || program) return !!program;
    const vs = compile(gl.VERTEX_SHADER, "attribute vec2 aPosition; void main(){gl_Position=vec4(aPosition,0.0,1.0);}");
    const fs = compile(gl.FRAGMENT_SHADER, FS);
    if (!vs || !fs) return false;
    program = gl.createProgram();
    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) return false;
    gl.useProgram(program);
    const vb = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vb);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);
    const a = gl.getAttribLocation(program, "aPosition");
    gl.enableVertexAttribArray(a);
    gl.vertexAttribPointer(a, 2, gl.FLOAT, false, 0, 0);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
    upload(makeMask(), 1, "uBurn");
    return true;
}

function resize() {
    width = window.innerWidth || 1280;
    height = window.innerHeight || 720;
    dpr = Math.min(window.devicePixelRatio || 1, 1.5);
    for (const c of [back, surface, front]) {
        c.width = Math.round(width * dpr);
        c.height = Math.round(height * dpr);
    }
    bg.setTransform(dpr, 0, 0, dpr, 0, 0);
    fg.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (gl) gl.viewport(0, 0, surface.width, surface.height);
}

function pose(t, current) {
    const dropping = current === "drop";
    const burning = current === "burn";
    const settled = dropping || burning;
    const enter = settled ? 1 : out(clamp((t - 0.03) / 0.42));
    const settle = settled ? 1 : smooth(0.28, 0.52, t);
    const burn = burning ? clamp((t - BURN_START) / (BURN_END - BURN_START)) : 0;
    const dropT = dropping ? out(clamp(t / 0.72)) : 0;
    const hover = (!settled && t > 0.5) ? Math.sin((t - 0.5) * 1.7) : 0;
    const h = Math.min(height * 0.30, width * 0.155);
    const size = mix(0.42, 1.0, enter) - 0.02 * settle;
    const ax = mix(0.42, -0.03, enter) + hover * 0.045 + dropT * 0.28;
    const ay = mix(1.15, 0.06, enter) + hover * 0.05;
    const az = mix(-0.42, 0.02, enter) + hover * 0.03 - burn * 0.02;
    const sx = Math.sin(ax), cx = Math.cos(ax), sy = Math.sin(ay), cy = Math.cos(ay), sz = Math.sin(az), cz = Math.cos(az);
    const restX = width * 0.18;
    const restY = height * 0.40;
    return {
        x: mix(restX + 36, restX, enter),
        y: mix(height + h * 0.35, restY, enter) - hover * 10 + dropT * (height * 0.78) - burn * 8,
        w: h * 0.64 * size * (1 - dropT * 0.08),
        h: h * size * (1 - dropT * 0.08),
        axisX: [cz * cy, sz * cy, -sy],
        axisY: [cz * sy * sx - sz * cx, sz * sy * sx + cz * cx, cy * sx],
        normal: [cz * sy * cx + sz * sx, sz * sy * cx - cz * sx, cy * cx],
        focal: height * 2.8,
        dropT,
    };
}

function project(x, y, p) {
    const a = (x - 0.5) * p.w, b = (y - 0.5) * p.h;
    const px = p.axisX[0] * a + p.axisY[0] * b;
    const py = p.axisX[1] * a + p.axisY[1] * b;
    const pz = p.axisX[2] * a + p.axisY[2] * b;
    const k = p.focal / (p.focal - pz);
    return { x: p.x + px * k, y: p.y + py * k };
}

function glow(c, x, y, r, alpha, color = "255,120,30") {
    if (alpha <= 0.0001 || r < 1) return;
    const g = c.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, `rgba(${color},${clamp(alpha)})`);
    g.addColorStop(0.27, `rgba(${color},${clamp(alpha * 0.27)})`);
    g.addColorStop(1, `rgba(${color},0)`);
    c.fillStyle = g;
    c.fillRect(x - r, y - r, r * 2, r * 2);
}

function ring(c, x, y, r, alpha, rotation = 0) {
    if (alpha <= 0) return;
    c.save();
    c.translate(x, y);
    c.rotate(rotation);
    c.strokeStyle = `rgba(255,170,60,${alpha})`;
    c.lineWidth = 0.9;
    for (let i = 0; i < 7; i++) { c.beginPath(); c.arc(0, 0, r, i * TAU / 7 + 0.07, (i + 1) * TAU / 7 - 0.15); c.stroke(); }
    c.restore();
}

function atmosphere(t, p, current) {
    bg.clearRect(0, 0, width, height);
    if (current === "drop") return;
    const arrival = Math.exp(-Math.pow((t - 0.21) / 0.105, 2));
    const pulse = current === "hold" ? 0.22 + Math.sin(t * 2.1) * 0.05 : 0;
    const sustain = current === "burn"
        ? smooth(0.08, 0.35, t) * (1 - smooth(1.92, 2.45, t))
        : pulse + arrival * 0.35;
    bg.globalCompositeOperation = "lighter";
    glow(bg, p.x, p.y, p.h * 0.85, 0.18 * sustain + 0.22 * arrival);
    if (current !== "hold" || t < 0.7) {
        const reveal = clamp((t - 0.08) / 0.47);
        ring(bg, p.x, p.y, p.h * 0.62 * (0.54 + 0.46 * out(reveal)), Math.sin(reveal * Math.PI) * 0.35, -0.7 + t * 0.2);
    }
    bg.globalCompositeOperation = "source-over";
}

function spark(c, x, y, vx, vy, size, alpha, white = false) {
    c.strokeStyle = white ? `rgba(255,236,180,${alpha})` : `rgba(255,110,20,${alpha})`;
    c.lineWidth = size;
    c.lineCap = "round";
    c.beginPath();
    c.moveTo(x - vx * 0.025, y - vy * 0.025);
    c.lineTo(x, y);
    c.stroke();
    c.fillStyle = `rgba(255,220,140,${alpha})`;
    c.beginPath();
    c.arc(x, y, size * 0.5, 0, TAU);
    c.fill();
}

function particles(t, p) {
    fg.clearRect(0, 0, width, height);
    fg.globalCompositeOperation = "lighter";
    const scale = Math.min(height / 450, width / 600, 1.1);
    for (const a of pieces) {
        const age = t - a.birth;
        if (age < 0 || age > a.life) continue;
        const origin = project(a.x, a.y, pose(a.birth));
        const dx = (a.x - 0.5) * 2, dy = (a.y - 0.5) * 2;
        const vx = (dx * a.speed + Math.sin(a.phase) * 24) * scale;
        const vy = (dy * a.speed * 0.55 - 42) * scale;
        const x = origin.x + vx * age + Math.sin(age * 9 + a.phase) * age * 15 * scale;
        const y = origin.y + vy * age - 30 * age * age * scale;
        const alpha = Math.pow(1 - age / a.life, 1.2);
        const size = a.size * scale;
        if (a.ash) {
            fg.save();
            fg.translate(x, y);
            fg.rotate(a.phase + age * 7);
            fg.globalCompositeOperation = "source-over";
            fg.fillStyle = `rgba(90,70,55,${alpha * 0.7})`;
            fg.beginPath();
            fg.moveTo(-size * 2, -size);
            fg.lineTo(size * 2.3, 0);
            fg.lineTo(-size, size * 2);
            fg.closePath();
            fg.fill();
            fg.restore();
        } else spark(fg, x, y, vx, vy, size, alpha, age < 0.07);
    }
    const endAge = t - 2.075;
    if (endAge >= 0 && endAge < 0.525) {
        const flash = Math.exp(-Math.pow((endAge - 0.025) / 0.045, 2));
        const endPose = pose(t, mode);
        glow(fg, endPose.x, endPose.y, endPose.h * 0.45, flash * 0.45, "255,140,40");
        for (const a of impact) {
            if (endAge > a.life) continue;
            const r = (5 + a.speed * endAge) * scale;
            const alpha = Math.pow(1 - endAge / a.life, 1.4);
            spark(fg, endPose.x + Math.cos(a.angle) * r, endPose.y + Math.sin(a.angle) * r * 0.68, Math.cos(a.angle) * a.speed, Math.sin(a.angle) * a.speed * 0.68, a.size * scale, alpha, endAge < 0.09);
        }
    }
    fg.globalCompositeOperation = "source-over";
}

function render() {
    const dropping = mode === "drop";
    const holding = mode === "hold";
    const t = dropping ? elapsed : (holding ? elapsed : clamp(elapsed / BASE) * BASE);
    const p = pose(t, mode);
    const progress = holding || dropping ? 0 : clamp((t - BURN_START) / (BURN_END - BURN_START));
    const opacity = dropping
        ? (1 - p.dropT)
        : (holding ? smooth(0.04, 0.16, Math.min(t, 0.4)) : smooth(0.045, 0.14, t) * (1 - smooth(2.105, 2.14, t)));
    atmosphere(t, p, mode);
    gl.uniform2f(U("uResolution"), surface.width, surface.height);
    gl.uniform2f(U("uSize"), width, height);
    gl.uniform2f(U("uCenter"), p.x, p.y);
    gl.uniform2f(U("uCardSize"), p.w, p.h);
    gl.uniform3fv(U("uAxisX"), p.axisX);
    gl.uniform3fv(U("uAxisY"), p.axisY);
    gl.uniform3fv(U("uNormal"), p.normal);
    gl.uniform1f(U("uFocal"), p.focal);
    gl.uniform1f(U("uProgress"), progress);
    gl.uniform1f(U("uTime"), t);
    gl.uniform1f(U("uOpacity"), opacity);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    if (!holding && !dropping) particles(t, p);
    else fg.clearRect(0, 0, width, height);
}

function frame(now) {
    if (!playing) return;
    const dt = last ? Math.min((now - last) / 1000, 0.05) : 0;
    last = now;
    elapsed += dt;
    render();
    if (mode === "burn" && elapsed >= BASE + 0.15) {
        stopShow();
        return;
    }
    if (mode === "drop" && elapsed >= 0.78) {
        stopShow();
        return;
    }
    raf = requestAnimationFrame(frame);
}

function stopShow() {
    playing = false;
    mode = "hold";
    if (raf) cancelAnimationFrame(raf);
    raf = 0;
    stage.classList.add("hidden");
    bg.clearRect(0, 0, width, height);
    fg.clearRect(0, 0, width, height);
}

function resize() {
    width = window.innerWidth || 1280;
    height = window.innerHeight || 720;
    dpr = Math.min(window.devicePixelRatio || 1, 1.5);
    for (const c of [back, surface, front]) {
        c.width = Math.round(width * dpr);
        c.height = Math.round(height * dpr);
    }
    bg.setTransform(dpr, 0, 0, dpr, 0, 0);
    fg.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (gl && program) gl.viewport(0, 0, surface.width, surface.height);
}

function begin(image, nextMode) {
    if (!initGl()) return;
    gl.useProgram(program);
    const tex = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
    gl.uniform1i(U("uCard"), 0);
    resize();
    elapsed = 0;
    last = 0;
    mode = nextMode || "hold";
    stage.classList.remove("hidden");
    playing = true;
    raf = requestAnimationFrame(frame);
}

function showCard(image, nextMode) {
    stopShow();
    const img = new Image();
    img.onload = () => begin(img, nextMode || "hold");
    img.onerror = () => begin(document.createElement("canvas"), nextMode || "hold");
    img.src = image || "card.png";
}

function dropCard() {
    if (!playing) return;
    mode = "drop";
    elapsed = 0;
    last = 0;
}

function burnCard() {
    if (!playing) return;
    mode = "burn";
    elapsed = BURN_START;
    last = 0;
}

function resourceName() {
    try { return GetParentResourceName(); } catch (_) { return "hh_magic"; }
}
function nuiPost(endpoint, data) {
    return fetch(`https://${resourceName()}/${endpoint}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data || {}),
    });
}
function closeGiver() {
    giver.classList.add("hidden");
    giverGrid.innerHTML = "";
    nuiPost("giverClose", {});
}
function openGiver(payload) {
    stopShow();
    giverTitle.textContent = (payload && payload.title) || "Magic Cards";
    giverGrid.innerHTML = "";
    const cards = (payload && payload.cards) || [];
    if (!cards.length) {
        const empty = document.createElement("p");
        empty.className = "giver-empty";
        empty.textContent = "No cards configured.";
        giverGrid.appendChild(empty);
    } else {
        for (const entry of cards) {
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "giver-card";
            const img = document.createElement("img");
            img.src = entry.image || "card.png";
            img.alt = entry.label || entry.id;
            const label = document.createElement("span");
            label.className = "giver-card-label";
            label.textContent = entry.label || entry.id;
            const item = document.createElement("span");
            item.className = "giver-card-item";
            item.textContent = entry.item || "";
            btn.appendChild(img);
            btn.appendChild(label);
            btn.appendChild(item);
            btn.addEventListener("click", () => nuiPost("giverGive", { spellId: entry.id }));
            giverGrid.appendChild(btn);
        }
    }
    giver.classList.remove("hidden");
}

giverClose.addEventListener("click", closeGiver);
document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !giver.classList.contains("hidden")) closeGiver();
});
window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (data.action === "showCard" || data.action === "tarot:play") {
        showCard(data.image || "card.png", data.mode || "hold");
        return;
    }
    if (data.action === "dropCard") {
        dropCard();
        return;
    }
    if (data.action === "burnCard") {
        burnCard();
        return;
    }
    if (data.action === "hideCard") {
        stopShow();
        return;
    }
    if (data.action === "openGiver") openGiver(data);
    if (data.action === "closeGiver") {
        giver.classList.add("hidden");
        giverGrid.innerHTML = "";
    }
    if (data.action === "ravenHud") {
        const hud = document.getElementById("raven-hud");
        const vignette = document.getElementById("raven-vignette");
        const time = document.getElementById("raven-time");
        if (!hud) return;
        if (!data.show) {
            hud.classList.add("hidden");
            return;
        }
        hud.classList.remove("hidden");
        if (time) time.textContent = String(data.seconds || 0);
        if (vignette) vignette.style.opacity = String(0.88 + (Number(data.warn) || 0) * 0.12);
    }
    if (data.action === "oathTimer") {
        const timer = document.getElementById("oath-timer");
        const time = document.getElementById("oath-time");
        if (!timer) return;
        if (!data.show) {
            timer.classList.add("hidden");
            return;
        }
        timer.classList.remove("hidden");
        if (time) time.textContent = String(data.seconds || 0);
    }
});
window.addEventListener("resize", () => { if (playing) resize(); });
