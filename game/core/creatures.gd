extends Node

const EXTRA := {
	"01-sinek": ["Sinek", "Serbest uçuş, dar deliklerden geçer.", "Free flight, slips through tiny gaps.", "Bedava keşif ve gözcülük; ölümü ucuz.", "Free scouting; cheap to lose.", Color("8fd3ff"), 0.7],
	"02-orumcek": ["Örümcek", "Duvara tırmanır; ağ köprüsü ve ağ tuzağı kurar.", "Climbs walls; spins web bridges and traps.", "Dikey erişim, düşman yavaşlatma.", "Vertical access, slows enemies.", Color("b49cff"), 0.85],
	"03-peygamber-devesi": ["Peygamber Devesi", "Doğru zamanlanmış savuşturma hasarı geri yansıtır.", "A well-timed parry reflects damage.", "Beceri isteyen düellocu.", "A skill-based duellist.", Color("9be36b"), 1.05],
	"04-karinca-aslani": ["Karınca Aslanı", "Toprağa gömülür; çukur tuzağı kazar.", "Burrows underground; digs pit traps.", "Pusucu; devriyeleri eler.", "Ambusher; picks off patrols.", Color("d8b37a"), 0.85],
	"05-akrep": ["Akrep", "Zehirli iğne: vuruş üstüne süreli hasar.", "Poison sting: damage over time.", "Zırhlı düşmanlara ekonomik cevap.", "Cheap answer to armoured foes.", Color("ff9d5c"), 0.95],
	"06-kurbaga": ["Kurbağa", "Dil kancasıyla tutunur, süper zıplar.", "Tongue grapple and a super jump.", "Dikey ve yatay geçişin ustası.", "Master of traversal.", Color("6be38b"), 1.0],
	"07-kus": ["Kuş", "Dalış saldırısı: yükseklik hasar demektir.", "Dive attack: height is damage.", "Hızlı geçiş ve vur-kaç.", "Fast travel and hit-and-run.", Color("7fc8ff"), 0.95],
	"08-yarasa": ["Yarasa", "Ekolokasyon karanlığı ve gizli geçitleri açığa çıkarır.", "Echolocation reveals darkness and hidden paths.", "Karanlık bölgelerin anahtarı.", "Key to the dark zones.", Color("c08bff"), 0.95],
	"09-aksolotl": ["Aksolotl", "Su altında nefes alır; dururken can yeniler.", "Breathes underwater; regenerates while still.", "Su bölümleri ve şifa.", "Water levels and healing.", Color("ff9ed0"), 0.95],
	"10-bukalemun": ["Bukalemun", "Kamuflaj: düşmanlar görmez.", "Camouflage: enemies can't see you.", "Savaşmadan sızma.", "Sneak past without a fight.", Color("8be3c8"), 0.95],
	"11-kirpi": ["Kirpi", "Diken zırhı temas edene hasar verir; top gibi yuvarlanır.", "Thorn armour hurts attackers; rolls like a ball.", "Savunmacı koridor temizleyici.", "Defensive corridor clearer.", Color("e0b07a"), 0.9],
	"12-slime": ["Slime", "İkiye bölünür: klon düğmeye basar ya da feda edilir.", "Splits in two: the clone presses switches.", "Bulmaca anahtarı.", "The puzzle key.", Color("8cff9e"), 0.85],
	"13-yilan-baligi": ["Yılan Balığı", "Elektrik alanı sudaki her şeye vurur; suda çok hızlı.", "Electric field shocks the water; fast swimmer.", "Su savaşının kralı.", "King of water combat.", Color("ffe36b"), 1.0],
	"14-kedi": ["Kedi", "Çift zıplama; ölümcül darbede bir kez dirilir.", "Double jump; survives one lethal blow.", "Riskli platformların sigortası.", "Insurance for risky jumps.", Color("ffc36b"), 1.1],
	"15-geyik": ["Geyik", "Boynuz hücumu duvar kırar, düşman fırlatır.", "Antler charge breaks walls and flings foes.", "Kırılabilir engellerin çözümü.", "Breaker of barriers.", Color("d89a6b"), 1.8],
	"16-ahtapot": ["Ahtapot", "Dar borulardan sıkışarak geçer; mürekkep kör eder.", "Squeezes through pipes; ink blinds.", "Erişilmez alanlar ve kaçış.", "Hard-to-reach places, escapes.", Color("ff7a9c"), 1.2],
	"17-kurt": ["Kurt", "Sürü çağrısı: iki hayalet kurt savaşır.", "Pack call: two ghost wolves fight with you.", "Sürekli savaşın omurgası.", "Backbone of sustained combat.", Color("a8b4c8"), 1.5],
	"18-kartal": ["Kartal", "Yüksek uçuş; nesneleri ve düşmanları kapıp bırakır.", "Soars high; grabs and drops things.", "Hava hakimiyeti, taşıma bulmacaları.", "Air control, carry puzzles.", Color("e8d29a"), 1.5],
	"19-ayi": ["Ayı", "Kükreme sersemletir; ağır engelleri parçalar.", "Roar stuns; smashes heavy obstacles.", "Yürüyen kale.", "A walking fortress.", Color("c9875a"), 2.0],
	"20-ejderha": ["Ejderha", "Alev nefesi; her engeli aşar.", "Fire breath; overcomes every obstacle.", "Son form, güç fantezisi.", "The apex form.", Color("ff6b4a"), 2.3],
}

var all: Array[CreatureDef] = []
var by_id: Dictionary = {}
var rules: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open("res://data/creatures.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	rules = d.get("ozRules", {})
	for c in d.get("creatures", []):
		var def := CreatureDef.new()
		def.id = c["id"]
		def.key = str(c["id"]).substr(3)
		def.name_en = c.get("name", def.key)
		def.tier = int(c.get("tier", 1))
		def.oz_cost = int(c.get("ozCost", 1))
		def.hp = int(c.get("hp", 1))
		def.damage = int(c.get("damage", 1))
		def.speed = int(c.get("moveSpeed", 1))
		def.jump = int(c.get("jump", 0))
		def.flight = bool(c.get("flight", false))
		def.abilities = PackedStringArray(c.get("abilities", []))
		def.role = c.get("role", "")
		var e: Array = EXTRA.get(def.id, [def.name_en, "", "", "", "", Color.WHITE, 1.0])
		def.name_tr = e[0]
		def.ability_tr = e[1]
		def.ability_en = e[2]
		def.blurb_tr = e[3]
		def.blurb_en = e[4]
		def.accent = e[5]
		def.size_tiles = e[6]
		def.texture = load("res://assets/creatures/%s.png" % def.id)
		all.append(def)
		by_id[def.id] = def
		by_id[def.key] = def

func get_def(id: String) -> CreatureDef:
	return by_id.get(id)

func fallback() -> CreatureDef:
	return get_def(str(rules.get("fallbackForm", "sinek")))

func revert_refund() -> float:
	return float(rules.get("voluntaryRevertRefund", 0.5))

func starting_cap() -> int:
	return int(rules.get("startingOzCap", 6))
