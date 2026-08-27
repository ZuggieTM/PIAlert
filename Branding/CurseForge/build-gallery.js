const path = require("path");
const sharp = require("sharp");

const ROOT = __dirname;
const OUT = path.join(ROOT, "gallery");
const BACKGROUND = path.join(ROOT, "assets", "gallery-background.png");
const LOGO = path.join(ROOT, "assets", "pialert-mark.png");
const SCREENSHOTS = "C:\\Program Files (x86)\\World of Warcraft\\_retail_\\Screenshots";

const WIDTH = 2048;
const HEIGHT = 1152;
const COLORS = {
  white: "#f4f7fb",
  body: "#b7c5d2",
  muted: "#8295a7",
  teal: "#26d6b3",
  tealDark: "#123f3c",
  violet: "#a88cff",
  gold: "#f4c964",
  card: "#0d1522",
};

const slides = [
  {
    output: "01-pialert-hero.jpg",
    source: "WoWScrnShot_082726_170152.jpg",
    crop: { left: 1600, top: 210, width: 1856, height: 1160 },
    shot: { x: 760, y: 185, width: 1210, height: 756 },
    eyebrow: "POWER INFUSION ASSISTANT",
    title: ["Give PI to the", "right player."],
    body: [
      "PIAlert turns whispers and major cooldowns",
      "into clear, immediate targeting cues.",
    ],
    pills: ["Whispers", "Cooldowns", "Raidframes"],
    caption: "See the request. Find the player. Cast Power Infusion.",
  },
  {
    output: "02-alerts.jpg",
    source: "WoWScrnShot_082726_170024.jpg",
    crop: { left: 2659, top: 125, width: 1512, height: 945 },
    shot: { x: 760, y: 185, width: 1210, height: 756 },
    eyebrow: "CUSTOM ALERTS",
    title: ["Never miss", "a PI request."],
    body: [
      "Choose animated raidframe glows, icons,",
      "cooldown swipes, sounds and a movable aura.",
    ],
    bullets: ["Pixel and AutoCast glows", "PI or tracked-spell icons", "Whisper-only sound controls"],
  },
  {
    output: "03-requests.jpg",
    source: "WoWScrnShot_082726_170021.jpg",
    crop: { left: 2659, top: 125, width: 1512, height: 945 },
    shot: { x: 760, y: 185, width: 1210, height: 756 },
    eyebrow: "REQUEST CONTROL",
    title: ["You decide who", "can ask for PI."],
    body: [
      "Accept whispers, tracked spell casts, or both—",
      "then limit requests to the players you trust.",
    ],
    bullets: ["Custom whisper phrases", "Group or priority-player rules", "Configurable fallback behavior"],
  },
  {
    output: "04-spells.jpg",
    source: "WoWScrnShot_082726_170044.jpg",
    crop: { left: 2659, top: 125, width: 1512, height: 945 },
    shot: { x: 760, y: 185, width: 1210, height: 756 },
    eyebrow: "COOLDOWN TRACKING",
    title: ["Track the", "cooldowns that", "matter."],
    body: [
      "Enable built-in class cooldowns or add your own.",
      "Talent-aware notes explain special requirements.",
    ],
    bullets: ["Class-organized presets", "Custom spell support", "Multiple aura IDs per cooldown"],
  },
  {
    output: "05-macros.jpg",
    source: "WoWScrnShot_082726_170047.jpg",
    crop: { left: 2659, top: 125, width: 1512, height: 945 },
    shot: { x: 760, y: 185, width: 1210, height: 756 },
    eyebrow: "BUILT-IN MACROS",
    title: ["One click to the", "right target."],
    body: [
      "Create safe Power Infusion macros without",
      "copying syntax or editing macro text by hand.",
    ],
    bullets: ["Player targeting", "Focus targeting", "Mouseover fallback"],
  },
];

function escapeXml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function textLines(lines, x, y, options = {}) {
  const size = options.size || 32;
  const gap = options.gap || Math.round(size * 1.22);
  const weight = options.weight || 400;
  const color = options.color || COLORS.white;
  const family = options.family || "Segoe UI, Arial, sans-serif";
  return lines.map((line, index) =>
    `<text x="${x}" y="${y + index * gap}" fill="${color}" font-family="${family}" font-size="${size}" font-weight="${weight}" letter-spacing="${options.spacing || 0}">${escapeXml(line)}</text>`
  ).join("");
}

function pillSvg(labels, startX, y) {
  let x = startX;
  return labels.map((label) => {
    const width = 54 + label.length * 14;
    const svg = `
      <rect x="${x}" y="${y}" width="${width}" height="50" rx="25" fill="#102a2b" stroke="#2bbfa5" stroke-width="2"/>
      <text x="${x + width / 2}" y="${y + 33}" fill="#bffbef" text-anchor="middle" font-family="Segoe UI, Arial, sans-serif" font-size="21" font-weight="600">${escapeXml(label)}</text>`;
    x += width + 16;
    return svg;
  }).join("");
}

function bulletSvg(labels, x, y) {
  return labels.map((label, index) => {
    const rowY = y + index * 70;
    return `
      <circle cx="${x + 12}" cy="${rowY - 8}" r="11" fill="#143e3b" stroke="${COLORS.teal}" stroke-width="2"/>
      <path d="M ${x + 7} ${rowY - 8} l 4 4 l 7 -9" fill="none" stroke="#a8fff0" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
      <text x="${x + 40}" y="${rowY}" fill="${COLORS.body}" font-family="Segoe UI, Arial, sans-serif" font-size="25" font-weight="500">${escapeXml(label)}</text>`;
  }).join("");
}

function overlaySvg(slide) {
  const titleStart = 365;
  const titleGap = 88;
  const bodyStart = titleStart + slide.title.length * titleGap + 28;
  const accentY = 263;
  const extras = slide.pills
    ? pillSvg(slide.pills, 118, bodyStart + 130)
    : bulletSvg(slide.bullets, 120, bodyStart + 155);

  return Buffer.from(`
    <svg width="${WIDTH}" height="${HEIGHT}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="leftShade" x1="0" x2="1">
          <stop offset="0" stop-color="#070b13" stop-opacity="0.96"/>
          <stop offset="0.72" stop-color="#070b13" stop-opacity="0.72"/>
          <stop offset="1" stop-color="#070b13" stop-opacity="0"/>
        </linearGradient>
        <linearGradient id="footer" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stop-color="#1ed0ac"/>
          <stop offset="0.5" stop-color="#7e65ff"/>
          <stop offset="1" stop-color="#1ed0ac" stop-opacity="0"/>
        </linearGradient>
        <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="18"/>
        </filter>
      </defs>
      <rect x="0" y="0" width="900" height="1152" fill="url(#leftShade)"/>
      <rect x="118" y="${accentY}" width="94" height="5" rx="2.5" fill="${COLORS.teal}"/>
      <text x="118" y="244" fill="${COLORS.teal}" font-family="Segoe UI, Arial, sans-serif" font-size="22" font-weight="700" letter-spacing="4">${escapeXml(slide.eyebrow)}</text>
      ${textLines(slide.title, 112, titleStart, { size: slide.eyebrow === "COOLDOWN TRACKING" ? 68 : 76, gap: titleGap, weight: 650, family: "Georgia, serif", spacing: -2 })}
      ${textLines(slide.body, 118, bodyStart, { size: 28, gap: 42, weight: 400, color: COLORS.body })}
      ${extras}
      ${slide.caption ? `<text x="118" y="1002" fill="${COLORS.white}" font-family="Segoe UI, Arial, sans-serif" font-size="24" font-weight="600">${escapeXml(slide.caption)}</text>` : ""}
      <rect x="118" y="1070" width="560" height="3" fill="url(#footer)"/>
      <text x="118" y="1110" fill="${COLORS.muted}" font-family="Segoe UI, Arial, sans-serif" font-size="19" font-weight="600" letter-spacing="2">PIALERT  •  /PIA</text>
    </svg>
  `);
}

async function screenshotBuffer(slide) {
  const input = path.join(SCREENSHOTS, slide.source);
  const { width, height } = slide.shot;
  const image = await sharp(input)
    .extract(slide.crop)
    .resize(width, height, { fit: "fill" })
    .gamma(1.8)
    .linear(1.08, 4)
    .modulate({ saturation: 1.06 })
    .sharpen({ sigma: 0.8 })
    .png()
    .toBuffer();
  return image;
}

async function buildSlide(slide) {
  const screenshot = await screenshotBuffer(slide);
  const logo = await sharp(LOGO)
    .resize(126, 126, { fit: "cover" })
    .png()
    .toBuffer();

  await sharp(BACKGROUND)
    .resize(WIDTH, HEIGHT, { fit: "cover" })
    .modulate({ brightness: 0.84, saturation: 0.9 })
    .composite([
      { input: screenshot, left: slide.shot.x, top: slide.shot.y },
      { input: overlaySvg(slide), left: 0, top: 0 },
      { input: logo, left: 112, top: 76 },
    ])
    .jpeg({ quality: 92, chromaSubsampling: "4:4:4", mozjpeg: true })
    .toFile(path.join(OUT, slide.output));
}

(async () => {
  for (const slide of slides) {
    await buildSlide(slide);
    console.log(`Built ${slide.output}`);
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
