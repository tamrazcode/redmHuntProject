const fs = require('fs');
const path = require('path');

const srcDir = path.join(__dirname);
const dstDirs = [
  path.join(__dirname, '..', 'thehunt_inventory', 'html', 'images'),
  path.join(__dirname, '..', 'thehunt_crafting', 'html', 'images')
];

for (const dstDir of dstDirs) {
  if (!fs.existsSync(dstDir)) {
    fs.mkdirSync(dstDir, { recursive: true });
  }
}

const mapping = {
  "Бутылка с водой.png": "bottle_water.png",
  "Пустая бутылка.png": "bottle_empty.png",
  "Яблоко.png": "apple.png",
  "Манго.png": "mango.png",
  "Груша.png": "pear.png",
  "Древесина.png": "wood_log.png",
  "Доска.png": "wood_plank.png",
  "Камень.png": "stone.png",
  "Железная руда.png": "iron_ore.png",
  "Железный слиток.png": "iron_ingot.png",
  "Стекло.png": "glass.png",
  "Ключ.png": "house_key.png",
  "Сырая курица.png": "meat_bird_raw.png",
  "Жареная курица.png": "meat_bird_cooked.png",
  "Сырая крольчатина.png": "meat_rabbit_raw.png",
  "Жареная крольчатина.png": "meat_rabbit_cooked.png",
  "Свиной окорок.png": "meat_pork_raw.png",
  "Жареный окорок.png": "meat_pork_cooked.png",
  "Сырая говядина.png": "meat_beef_raw.png",
  "Жареная говядина.png": "meat_beef_cooked.png",
  "Сырая оленина.png": "meat_deer_raw.png",
  "Жареная оленина.png": "meat_deer_cooked.png",
  "Сырая медвежатина.png": "meat_bear_raw.png",
  "Жареная медвежатина.png": "meat_bear_cooked.png",
  "Бинт.png": "bandage.png",
  "Ветка.png": "twigs.png",
  "Костёр.png": "campfire.png",
  "Лист лопуха.png": "burdock_leaf.png",
  "Повязка с лопухом.png": "bandage_burdock.png",
  "Ткань.png": "cloth.png"
};

const files = fs.readdirSync(srcDir);

for (const dstDir of dstDirs) {
  let count = 0;
  for (const file of files) {
    if (mapping[file]) {
      const srcFile = path.join(srcDir, file);
      const dstFile = path.join(dstDir, mapping[file]);
      fs.copyFileSync(srcFile, dstFile);
      count++;
    }
  }
  console.log(`Successfully copied ${count} images to ${dstDir}`);
}
