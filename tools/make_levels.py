"""Below Hell bölüm üreticisi: koordinatlı yerleşimden ASCII bölüm dosyaları yazar."""
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "levels")


class Map:
    def __init__(self, w, h, meta):
        self.w, self.h, self.meta = w, h, meta
        self.g = [[" "] * w for _ in range(h)]
        self.darks = []
        self.fill(0, 0, 0, h - 1, "#")
        self.fill(w - 1, 0, w - 1, h - 1, "#")

    def fill(self, x0, y0, x1, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                if 0 <= x < self.w and 0 <= y < self.h:
                    self.g[y][x] = c

    def put(self, x, y, c):
        self.g[y][x] = c

    def floor(self, x0, x1, top):
        self.fill(x0, top, x1, self.h - 1, "#")

    def dark(self, x0, y0, x1, y1):
        self.darks.append(f"{x0},{y0},{x1 - x0 + 1},{y1 - y0 + 1}")

    def save(self, name):
        if self.darks:
            self.meta["dark"] = ";".join(self.darks)
        lines = [f"{k}: {v}" for k, v in self.meta.items()] + ["---"] + ["".join(r).rstrip() for r in self.g]
        with open(os.path.join(OUT, name), "w") as fh:
            fh.write("\n".join(lines) + "\n")
        n_oz = sum(r.count("o") + 3 * r.count("O") for r in self.g)
        print(name, self.w, "x", self.h, "oz", n_oz)


def level1():
    m = Map(112, 18, {"name_tr": "I · Uyanış", "name_en": "I · Awakening",
                      "hint_tr": "Öz topla · Q basılı tut ve Kurbağa'ya dönüş", "hint_en": "Gather Essence · Hold Q and become the Frog",
                      "theme": "graveyard", "music": "level", "oz_cap": 6, "next_cap": 8, "tint": "#f2e8ff"})
    m.floor(1, 22, 14)
    m.put(4, 13, "S")
    m.fill(14, 13, 16, 13, "#")
    for x in (8, 10, 12):
        m.put(x, 12, "o")
    m.fill(18, 11, 21, 11, "=")
    m.put(19, 10, "o")
    m.put(20, 10, "o")
    m.put(6, 13, "T")
    m.floor(23, 24, 10)
    m.floor(25, 44, 14)
    m.put(34, 13, "i")
    m.put(30, 12, "o")
    m.put(38, 12, "o")
    m.put(27, 13, "T")
    m.floor(45, 49, 17)
    m.fill(45, 16, 49, 16, "^")
    m.floor(50, 59, 14)
    m.put(52, 13, "C")
    m.put(56, 12, "o")
    m.put(58, 7, "g")
    m.floor(60, 110, 8)
    for x in (64, 66, 68):
        m.put(x, 6, "o")
    m.put(72, 7, "i")
    m.put(82, 7, "i")
    m.fill(86, 3, 91, 3, "#")
    m.fill(91, 3, 91, 7, "#")
    m.fill(86, 4, 86, 7, "?")
    m.put(89, 6, "O")
    m.put(78, 7, "T")
    m.fill(94, 6, 97, 6, "=")
    m.put(95, 5, "o")
    m.put(104, 7, "X")
    m.put(100, 7, "T")
    m.save("01_uyanis.txt")


def level2():
    m = Map(126, 20, {"name_tr": "II · Batık Sular", "name_en": "II · Sunken Waters",
                      "hint_tr": "Nefes alamayanlar suda boğulur · Aksolotl ya da Yılan Balığı", "hint_en": "Air-breathers drown · try the Axolotl or the Eel",
                      "theme": "mountain", "music": "level", "oz_cap": 8, "next_cap": 10, "tint": "#e6f0ff"})
    m.floor(1, 30, 15)
    m.put(4, 14, "S")
    for x in (7, 9, 11, 13):
        m.put(x, 13, "o")
    m.fill(16, 12, 20, 12, "=")
    m.put(18, 11, "o")
    m.put(25, 14, "i")
    m.put(22, 11, "O")
    m.fill(21, 12, 23, 12, "=")
    m.floor(31, 62, 19)
    m.fill(31, 15, 62, 18, "~")
    m.fill(34, 0, 58, 14, "#")
    m.fill(44, 17, 45, 18, "#")
    m.fill(51, 15, 52, 16, "#")
    for x in (38, 47, 55):
        m.put(x, 17, "o")
    m.put(60, 18, "O")
    m.floor(63, 124, 15)
    m.put(74, 14, "C")
    m.put(80, 14, "i")
    m.put(88, 14, "k")
    m.fill(84, 11, 87, 11, "=")
    m.put(85, 10, "o")
    m.put(86, 10, "o")
    m.floor(92, 96, 19)
    m.fill(92, 13, 96, 18, "~")
    m.put(94, 17, "O")
    m.fill(100, 12, 103, 12, "=")
    m.put(102, 7, "w")
    m.put(108, 14, "i")
    m.put(118, 14, "X")
    m.put(113, 14, "T")
    m.put(77, 14, "T")
    m.save("02_sular.txt")


def level3():
    m = Map(130, 20, {"name_tr": "III · Kör Mağaralar", "name_en": "III · Blind Caves",
                      "hint_tr": "Karanlıkta Yarasa görür · K: ekolokasyon", "hint_en": "The Bat sees in the dark · K: echolocation",
                      "theme": "graveyard", "music": "level2", "oz_cap": 10, "next_cap": 10, "tint": "#c9c0e0"})
    m.fill(0, 0, 129, 1, "#")
    m.floor(1, 24, 15)
    m.put(4, 14, "S")
    for x in (8, 10, 12):
        m.put(x, 14, "o")
    m.fill(15, 12, 18, 12, "=")
    m.put(16, 11, "o")
    m.put(17, 11, "o")
    m.put(21, 14, "T")
    m.floor(25, 64, 17)
    m.dark(25, 2, 64, 16)
    m.fill(28, 16, 31, 16, "^")
    m.fill(38, 16, 41, 16, "^")
    m.fill(48, 16, 52, 16, "^")
    m.fill(33, 13, 36, 13, "=")
    m.fill(43, 12, 46, 12, "=")
    m.fill(54, 13, 57, 13, "=")
    m.put(34, 12, "o")
    m.put(44, 11, "o")
    m.put(55, 12, "o")
    m.put(46, 8, "w")
    m.fill(25, 16, 27, 16, "#")
    m.fill(32, 16, 37, 16, "#")
    m.fill(42, 16, 47, 16, "#")
    m.fill(53, 16, 64, 16, "#")
    m.floor(65, 128, 15)
    m.put(67, 14, "C")
    m.put(72, 14, "T")
    m.put(78, 14, "i")
    m.put(84, 14, "i")
    m.fill(90, 2, 128, 8, "#")
    m.fill(92, 13, 100, 13, "#")
    m.fill(100, 14, 100, 14, "#")
    m.put(92, 14, "?")
    m.put(95, 14, "O")
    m.put(97, 14, "o")
    m.fill(104, 12, 107, 12, "=")
    m.put(105, 11, "o")
    m.put(112, 10, "w")
    m.dark(108, 9, 124, 14)
    m.fill(114, 14, 117, 14, "^")
    m.put(122, 14, "X")
    m.save("03_karanlik.txt")


def level4():
    m = Map(128, 20, {"name_tr": "IV · Kemik Ocağı", "name_en": "IV · Bone Quarry",
                      "hint_tr": "Çatlak duvarı Geyik kırar · Ağır kayayı yalnızca Ayı ve Ejderha", "hint_en": "The Stag breaks cracked walls · only Bear and Dragon smash boulders",
                      "theme": "snow", "music": "level2", "oz_cap": 10, "next_cap": 12, "tint": "#e8ecff"})
    m.floor(1, 126, 15)
    m.fill(1, 0, 126, 1, "#")
    m.put(4, 14, "S")
    for x in (8, 10, 12, 14, 16):
        m.put(x, 13, "o")
    m.put(11, 14, "T")
    m.fill(20, 11, 23, 11, "=")
    m.put(21, 10, "O")
    m.put(26, 14, "k")
    m.fill(30, 2, 31, 14, "#")
    m.fill(30, 11, 31, 14, "B")
    m.put(36, 14, "C")
    m.put(42, 14, "k")
    m.put(48, 14, "i")
    m.fill(44, 11, 47, 11, "=")
    m.put(45, 10, "o")
    m.put(46, 10, "o")
    m.fill(54, 2, 56, 14, "#")
    m.fill(54, 12, 56, 14, "H")
    m.put(60, 14, "o")
    m.put(62, 14, "O")
    m.put(64, 14, "P")
    m.fill(70, 2, 71, 14, "#")
    m.fill(70, 12, 71, 14, "d")
    m.put(67, 14, "T")
    m.put(76, 14, "C")
    m.put(82, 14, "k")
    m.put(90, 14, "k")
    m.fill(86, 11, 89, 11, "=")
    m.put(87, 10, "o")
    m.put(88, 10, "o")
    m.fill(96, 12, 99, 14, "#")
    m.fill(100, 10, 103, 14, "#")
    m.put(101, 9, "o")
    m.put(108, 14, "i")
    m.put(112, 14, "k")
    m.put(120, 14, "X")
    m.put(116, 14, "T")
    m.save("04_kemik.txt")


def level5():
    m = Map(90, 20, {"name_tr": "V · Ateş Tahtı", "name_en": "V · Throne of Fire",
                     "hint_tr": "Cehennemin bekçisini yen ve kapıdan çık", "hint_en": "Defeat the warden of hell and leave through the gate",
                     "theme": "desert", "music": "boss", "oz_cap": 12, "next_cap": 12, "tint": "#ffd9c9"})
    m.floor(1, 88, 15)
    m.put(4, 14, "S")
    for x in (7, 9, 11, 13, 15, 17):
        m.put(x, 13, "o")
    m.put(10, 10, "O")
    m.put(13, 10, "O")
    m.fill(8, 11, 15, 11, "=")
    m.put(20, 14, "C")
    m.put(22, 14, "T")
    m.fill(30, 11, 34, 11, "=")
    m.fill(54, 11, 58, 11, "=")
    m.fill(41, 8, 47, 8, "=")
    m.put(44, 14, "b")
    m.put(32, 10, "o")
    m.put(56, 10, "o")
    m.put(44, 7, "O")
    m.fill(62, 14, 64, 14, "^")
    m.fill(24, 14, 26, 14, "^")
    m.put(80, 14, "X")
    m.put(76, 14, "T")
    m.put(84, 14, "T")
    m.save("05_ates.txt")


if __name__ == "__main__":
    level1()
    level2()
    level3()
    level4()
    level5()
