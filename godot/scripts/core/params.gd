class_name Params
extends RefCounted
## 웹 params.js와 같은 게임 파라미터. 등급별 배열은 유전 가이드의 4등급(커먼·언커먼·레어·에픽)에 맞춰
## 웹 7등급 표의 앞 4칸 값을 사용한다.

const BREED_COOLDOWN_MS := 24.0 * 3600e3
const GROWTH_WINDOW_MS := 3600e3
const SPECIAL_CHANCE := 0.005
const FANTASY_CHANCE_ON_TOP := 0.10   # 최고 등급(에픽)에서만
const BODY_MUTATION_SIGMA := 0.08
const INCOME_PER_HOUR_BY_GRADE := [1, 2, 4, 8]
const INCOME_SPECIAL_PER_HOUR := 40
const INCOME_CAP_HOURS := 24
const SELL_PRICE_BY_GRADE := [10, 25, 60, 150]
const SELL_SPECIAL := 2500
const FANTASY_PRICE_MULT := 2
const CARRIER_BONUS_RATE := 0.15
const SHOP_BREED_MULT := 1.5
const DEX_REWARD_BY_GRADE := [5, 10, 20, 40]
const DEX_REWARD_SPECIAL := 500
const DEX_MILESTONE_EVERY := 25
const DEX_MILESTONE_REWARD := 200
const SHOP_SIZE := 8
const SHOP_REFRESH_MS := 6.0 * 3600e3
const START_COINS := 200
const PEN_LEVELS := [
	{"capacity": 6, "cost": 0}, {"capacity": 7, "cost": 240}, {"capacity": 9, "cost": 650},
	{"capacity": 11, "cost": 1400}, {"capacity": 13, "cost": 2800}, {"capacity": 15, "cost": 5200},
	{"capacity": 17, "cost": 9000}, {"capacity": 19, "cost": 15000},
]

const GRADES := ["커먼", "언커먼", "레어", "에픽"]
const GRADE_COLORS := ["#a9a18f", "#7bbf6a", "#5aa9e6", "#b07be0"]
const SPECIAL_GRADE := -1   # SPECIAL 품종은 grade = -1

## 창업(시작·샵·이웃) 개체군 대립유전자 빈도 (웹 FREQ에서 B의 b·bl을 b로 합침)
const FREQ := {
	"B": {"B": 0.70, "b": 0.30},
	"D": {"D": 0.70, "d": 0.30},
	"S": {"S": 0.28, "s": 0.72},
}
