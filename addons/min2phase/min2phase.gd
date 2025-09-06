# Min2Phase Rubik's Cube Solver
# GDScript port of the min2phase algorithm
# Based on Chen Shuang's Rust implementation
# 
# This is a two-phase solver that first solves to G1 subgroup (U,D,R2,L2,F2,B2)
# then solves to G0 subgroup (solved state).

extends Node
class_name Min2Phase

const SOLVED_CUBE = "UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB"

const INVERSE_SOLUTION = 0x01  # Flag for inverse solution
const USE_SEPARATOR = 0x02     # Flag for using separator in output
const APPEND_LENGTH = 0x04     # Flag for appending length to solution
const MAX_PREMV_LEN = 20       # Maximum length of pre-moves
const MIN_P1PRE_LEN = 7        # Minimum phase 1 pre-move length

# Size constants for various coordinate spaces
const N_FLIP = 2048        # Number of edge flip states
const N_FLIP_SYM = 336     # Number of edge flip states with symmetry
const N_TWST = 2187        # Number of corner twist states
const N_TWST_SYM = 324     # Number of corner twist states with symmetry
const N_SLICE = 495        # Number of slice states
const N_PERM = 40320       # Number of permutation states
const N_PERM_SYM = 2768    # Number of permutation states with symmetry
const N_MPERM = 24         # Number of middle edge permutation states
const N_CCOMB = 70         # Number of corner combination states

# Move constants
const N_MOVES_P1 = 18      # Number of moves in phase 1
const N_MOVES_P2 = 10      # Number of moves in phase 2
const MAX_DEPTH2 = 13      # Maximum depth for phase 2

static var MOVE2STR = ["U ", "U2", "U'", "R ", "R2", "R'", "F ", "F2", "F'", "D ", "D2", "D'", "L ", "L2", "L'", "B ", "B2", "B'"]

# URF move table from Rust - maps URF symmetry variants to move indices
# Each row represents a different URF symmetry variant
static var URF_MOVE = [
	[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],  # Identity
	[6, 7, 8, 0, 1, 2, 3, 4, 5, 15, 16, 17, 9, 10, 11, 12, 13, 14],  # F symmetry
	[3, 4, 5, 6, 7, 8, 0, 1, 2, 12, 13, 14, 15, 16, 17, 9, 10, 11],  # R symmetry
	[2, 1, 0, 5, 4, 3, 8, 7, 6, 11, 10, 9, 14, 13, 12, 17, 16, 15],  # F' symmetry
	[8, 7, 6, 2, 1, 0, 5, 4, 3, 17, 16, 15, 11, 10, 9, 14, 13, 12],  # R' symmetry
	[5, 4, 3, 8, 7, 6, 2, 1, 0, 14, 13, 12, 17, 16, 15, 11, 10, 9]   # F2 symmetry
]

# Face constants - offsets for each face in the facelet array
const U = 0   # Up face starts at index 0
const R = 9   # Right face starts at index 9
const F = 18  # Front face starts at index 18
const D = 27  # Down face starts at index 27
const L = 36  # Left face starts at index 36
const B = 45  # Back face starts at index 45

# Corner facelet positions [corner][facelet]
# Each corner has 3 facelets, this maps corner index to facelet indices
static var CORNER_FACELET = [
	[U + 8, R + 0, F + 2], [U + 6, F + 0, L + 2], [U + 0, L + 0, B + 2], [U + 2, B + 0, R + 2],
	[D + 2, F + 8, R + 6], [D + 0, L + 8, F + 6], [D + 6, B + 8, L + 6], [D + 8, R + 8, B + 6]
]

# Edge facelet positions [edge][facelet]
# Each edge has 2 facelets, this maps edge index to facelet indices
static var EDGE_FACELET = [
	[U + 5, R + 1], [U + 7, F + 1], [U + 3, L + 1], [U + 1, B + 1], [D + 5, R + 7], [D + 1, F + 7],
	[D + 3, L + 7], [D + 7, B + 7], [F + 5, R + 3], [F + 3, L + 5], [B + 5, L + 3], [B + 3, R + 5]
]

# Phase 2 moves - subset of moves used in phase 2 (G1 subgroup)
static var P2MOVES = [0, 1, 2, 4, 7, 9, 10, 11, 13, 16, 3, 5, 6, 8, 12, 14, 15, 17]

# Cubie structure - represents the cube state
class Cubie:
	var ca: PackedByteArray  # Corner array: 8 corners
	var ea: PackedByteArray  # Edge array: 12 edges
	
	func _init():
		ca.resize(8)
		ea.resize(12)
		reset()
	
	func reset():
		for i in range(8):
			ca[i] = i
		for i in range(12):
			ea[i] = i * 2
	
	func cmp(other: Cubie) -> int:
		for i in range(8):
			if ca[i] != other.ca[i]:
				return ca[i] - other.ca[i]
		for i in range(12):
			if ea[i] != other.ea[i]:
				return ea[i] - other.ea[i]
		return 0
	
	func clone() -> Cubie:
		var new_cubie = Cubie.new()
		new_cubie.ca = ca.duplicate()
		new_cubie.ea = ea.duplicate()
		return new_cubie

	func copy_from(c: Cubie) -> void:
		for i in range(8):
			ca[i] = c.ca[i]
		for i in range(12):
			ea[i] = c.ea[i]
	
	static func corn_mult(a: Cubie, b: Cubie, prod: Cubie):
		for cn in range(8):
			var ori_a = (a.ca[b.ca[cn] & 0x7] >> 3) & 0x7
			var ori_b = (b.ca[cn] >> 3) & 0x7
			var ori = ori_a + (ori_b if ori_a < 3 else (6 - ori_b))
			ori = (ori % 3) + (0 if (ori_a < 3) == (ori_b < 3) else 3)
			prod.ca[cn] = (a.ca[b.ca[cn] & 0x7] & 0x7) | (ori << 3)
	
	static func edge_mult(a: Cubie, b: Cubie, prod: Cubie):
		for ed in range(12):
			prod.ea[ed] = a.ea[(b.ea[ed] >> 1) & 0x1F] ^ (b.ea[ed] & 1)
	
	static func inv(src: Cubie, inv: Cubie):
		for ed in range(12):
			inv.ea[(src.ea[ed] >> 1) & 0x1F] = (ed * 2) | (src.ea[ed] & 0x1)
		for cn in range(8):
			inv.ca[(src.ca[cn] & 0x7)] = cn | (((0x20 >> (src.ca[cn] >> 3)) & 0x18))
	
	func get_flip() -> int:
		var idx = 0
		for i in range(11):
			idx = (idx << 1) | (ea[i] & 1)
		return idx
	
	func set_flip(idx: int):
		var parity = 0
		for i in range(10, -1, -1):
			var val = idx & 1
			idx >>= 1
			parity ^= val
			ea[i] = (ea[i] & ~1) | val
		ea[11] = (ea[11] & ~1) | parity
	
	func get_twst() -> int:
		var idx = 0
		for i in range(7):
			idx += (idx << 1) + ((ca[i] >> 3) & 0x7)
		return idx
	
	func set_twst(idx: int):
		var twst = 15
		for i in range(6, -1, -1):
			var val = idx % 3
			idx /= 3
			twst -= val
			ca[i] = (ca[i] & 0x7) | (val << 3)
		ca[7] = (ca[7] & 0x7) | ((twst % 3) << 3)
	
	func get_slice() -> int:
		var arr = []
		arr.resize(12)
		for i in range(12):
			arr[i] = ea[i] >> 1
		return 494 - Min2Phase.get_comb(arr, 12, 8)
	
	func set_slice(idx: int):
		var arr = []
		arr.resize(12)
		Min2Phase.set_comb(arr, 494 - idx, 12, 8)
		for i in range(12):
			ea[i] = (ea[i] & 1) | (arr[i] << 1)
	
	func get_cperm() -> int:
		var arr = []
		arr.resize(8)
		for i in range(8):
			arr[i] = ca[i] & 0x7
		return Min2Phase.get_nperm(arr, 8)
	
	func set_cperm(idx: int):
		var arr = []
		arr.resize(8)
		Min2Phase.set_nperm(arr, idx, 8)
		for i in range(8):
			ca[i] = (ca[i] & ~0x7) | arr[i]
	
	func get_eperm() -> int:
		var arr = []
		arr.resize(8)
		for i in range(8):
			arr[i] = (ea[i] >> 1) & 0x1F
		return Min2Phase.get_nperm(arr, 8)
	
	func set_eperm(idx: int):
		var arr = []
		arr.resize(8)
		Min2Phase.set_nperm(arr, idx, 8)
		for i in range(8):
			ea[i] = (ea[i] & 1) | (arr[i] << 1)
	
	func get_mperm() -> int:
		var arr = []
		arr.resize(4)
		for i in range(8, 12):
			arr[i - 8] = ((ea[i] >> 1) & 0x3)
		return Min2Phase.get_nperm(arr, 4)
	
	func set_mperm(idx: int):
		var arr = []
		arr.resize(4)
		Min2Phase.set_nperm(arr, idx, 4)
		for i in range(8, 12):
			ea[i] = (ea[i] & 1) | ((arr[i - 8] + 8) << 1)
	
	func get_ccomb() -> int:
		var arr = []
		arr.resize(8)
		for i in range(8):
			arr[i] = ca[i] & 0x7
		return Min2Phase.get_comb(arr, 8, 0)
	
	func set_ccomb(idx: int):
		var arr = []
		arr.resize(8)
		Min2Phase.set_comb(arr, idx, 8, 0)
		for i in range(8):
			ca[i] = (ca[i] & ~0x7) | arr[i]
	
	func verify() -> int:
		var sum = 0
		var edge_mask = 0
		for e in range(12):
			edge_mask |= 1 << ((ea[e] >> 1) & 0x1F)
			sum ^= ea[e] & 1
		if edge_mask != 0xFFF:
			return -2
		elif sum != 0:
			return -3
		
		var corn_mask = 0
		for c in range(8):
			corn_mask |= 1 << (ca[c] & 0x7)
			sum += (ca[c] >> 3) & 0x7
		if corn_mask != 0xFF:
			return -4
		elif sum % 3 != 0:
			return -5
		
		var parity = Min2Phase.get_nparity(get_cperm(), 8)
		var ea_copy = ea.duplicate()
		for i in range(12):
			while ((ea_copy[i] >> 1) & 0x1F) != i:
				var j = (ea_copy[i] >> 1) & 0x1F
				var temp = ea_copy[i]
				ea_copy[i] = ea_copy[j]
				ea_copy[j] = temp
				parity ^= 1
		if parity != 0:
			return -6
		return 0
	
	func random_reset():
		var cperm = randi() % N_PERM
		var parity = Min2Phase.get_nparity(cperm, 8)
		reset()
		set_cperm(cperm)
		set_twst(randi() % N_TWST)
		set_flip(randi() % N_FLIP)
		for i in range(10):
			var j = i + randi() % (12 - i)
			if i != j:
				var temp = ea[i]
				ea[i] = ea[j]
				ea[j] = temp
				parity ^= 1
		if parity != 0:
			var temp = ea[10]
			ea[10] = ea[11]
			ea[11] = temp
	
	func from_facelet(facelet: String) -> int:
		if facelet.length() < 54:
			return -1
		
		var f = []
		f.resize(54)
		var colors = [facelet[4], facelet[13], facelet[22], facelet[31], facelet[40], facelet[49]]
		var count = 0
		
		for i in range(54):
			var found = false
			for j in range(6):
				if facelet[i] == colors[j]:
					f[i] = j
					count += 1 << (j * 4)
					found = true
					break
			if not found:
				return -1
		
		if count != 0x999999:
			return -1
		
		reset()
		var ori
		for i in range(8):
			ori = 0
			while ori < 3:
				if f[Min2Phase.CORNER_FACELET[i][ori]] == 0 or f[Min2Phase.CORNER_FACELET[i][ori]] == 3:
					break
				ori += 1
			var col1 = f[Min2Phase.CORNER_FACELET[i][(ori + 1) % 3]]
			var col2 = f[Min2Phase.CORNER_FACELET[i][(ori + 2) % 3]]
			for j in range(8):
				if col1 == Min2Phase.CORNER_FACELET[j][1] / 9 and col2 == Min2Phase.CORNER_FACELET[j][2] / 9:
					ca[i] = (ori % 3) << 3 | j
					break
		
		for i in range(12):
			for j in range(12):
				if f[Min2Phase.EDGE_FACELET[i][0]] == Min2Phase.EDGE_FACELET[j][0] / 9 and f[Min2Phase.EDGE_FACELET[i][1]] == Min2Phase.EDGE_FACELET[j][1] / 9:
					ea[i] = j << 1
					break
				if f[Min2Phase.EDGE_FACELET[i][0]] == Min2Phase.EDGE_FACELET[j][1] / 9 and f[Min2Phase.EDGE_FACELET[i][1]] == Min2Phase.EDGE_FACELET[j][0] / 9:
					ea[i] = (j << 1) | 1
					break
		
		return 0
	
	func to_facelet() -> String:
		var colors = ['U', 'R', 'F', 'D', 'L', 'B']
		var f = []
		f.resize(54)
		for i in range(54):
			f[i] = i / 9
		
		for c in range(8):
			var j = ca[c] & 0x7
			var ori = (ca[c] >> 3) & 0x7
			for n in range(3):
				f[Min2Phase.CORNER_FACELET[c][(n + ori) % 3]] = Min2Phase.CORNER_FACELET[j][n] / 9
		
		for e in range(12):
			var j = (ea[e] >> 1) & 0x1F
			var ori = ea[e] & 1
			for n in range(2):
				f[Min2Phase.EDGE_FACELET[e][(n + ori) % 2]] = Min2Phase.EDGE_FACELET[j][n] / 9
		
		var buf = ""
		for i in range(54):
			buf += colors[f[i]]
		return buf

# Coordinate structure for phase 1
class Coord:
	var twst: int = 0
	var tsym: int = 0
	var flip: int = 0
	var fsym: int = 0
	var slice: int = 0
	var prun: int = 0
	
	func _init():
		pass
	
	func from_cubie(stbl: StaticTables, src: Cubie) -> int:
		slice = src.get_slice()
		flip = stbl.flip_raw2sym[src.get_flip()]
		fsym = flip & 7
		flip >>= 3
		twst = stbl.twst_raw2sym[src.get_twst()]
		tsym = twst & 7
		twst >>= 3
		prun = max(
			Min2Phase.get_pruning(stbl.slice_twst_prun, twst * N_SLICE + stbl.slice_conj[slice * 8 + tsym]),
			Min2Phase.get_pruning(stbl.slice_flip_prun, flip * N_SLICE + stbl.slice_conj[slice * 8 + fsym])
		)
		return prun
	
	func move_prun(sctx: StaticContext, stbl: StaticTables, src: Coord, mv: int) -> int:
		slice = stbl.slice_move[src.slice * N_MOVES_P1 + mv]
		flip = stbl.flip_move[src.flip * N_MOVES_P1 + sctx.symmove[mv][src.fsym]]
		fsym = (flip & 7) ^ src.fsym
		flip >>= 3
		twst = stbl.twst_move[src.twst * N_MOVES_P1 + sctx.symmove[mv][src.tsym]]
		tsym = (twst & 7) ^ src.tsym
		twst >>= 3
		prun = max(
			Min2Phase.get_pruning(stbl.slice_twst_prun, twst * N_SLICE + stbl.slice_conj[slice * 8 + tsym]),
			Min2Phase.get_pruning(stbl.slice_flip_prun, flip * N_SLICE + stbl.slice_conj[slice * 8 + fsym])
		)
		return prun

# Coordinate structure for phase 2
class Coord2:
	var edge: int = 0
	var esym: int = 0
	var corn: int = 0
	var csym: int = 0
	var mid: int = 0
	
	func _init():
		pass
	
	func from_cubie(sctx: StaticContext, stbl: StaticTables, src: Cubie) -> int:
		corn = Min2Phase.esym2csym(stbl.eperm_raw2sym[src.get_cperm()])
		csym = corn & 0xf
		corn = corn >> 4
		edge = stbl.eperm_raw2sym[src.get_eperm()]
		esym = edge & 0xf
		edge = edge >> 4
		mid = src.get_mperm()
		var edgei = Min2Phase.get_perm_sym_inv(sctx, stbl, edge, esym, 0)
		var corni = Min2Phase.get_perm_sym_inv(sctx, stbl, corn, csym, 1)
		return max(
			Min2Phase.get_pruning(stbl.ccomb_eperm_prun, (edgei >> 4) * N_CCOMB + stbl.ccomb_conj[stbl.cperm2comb[corni >> 4] * 16 + sctx.symmuli[edgei & 0xf][corni & 0xf]]),
			max(
				Min2Phase.get_pruning(stbl.ccomb_eperm_prun, edge * N_CCOMB + stbl.ccomb_conj[stbl.cperm2comb[corn] * 16 + sctx.symmuli[esym][csym]]),
				Min2Phase.get_pruning(stbl.mperm_cperm_prun, corn * N_MPERM + stbl.mperm_conj[mid * 16 + csym])
			)
		)

# Solution structure
class Solution:
	var depth1: int = 0
	var verbose: int = 0
	var urf_idx: int = 0
	var premv_len: int = 0
	var length: int = 0
	var moves: PackedByteArray
	
	func _init():
		moves.resize(31)
	
	func append_move(cur_move: int):
		if length == 0:
			moves[length] = cur_move
			length += 1
			return
		
		var cur_axis = cur_move / 3
		var last_axis = moves[length - 1] / 3
		
		if cur_axis == last_axis:
			var pow = (cur_move % 3 + moves[length - 1] % 3 + 1) % 4
			if pow == 3:
				length -= 1
			else:
				moves[length - 1] = cur_axis * 3 + pow
			return
		
		if length > 1 and cur_axis % 3 == last_axis % 3 and cur_axis == moves[length - 2] / 3:
			var pow = (cur_move % 3 + moves[length - 2] % 3 + 1) % 4
			if pow == 3:
				moves[length - 2] = moves[length - 1]
				length -= 1
			else:
				moves[length - 2] = cur_axis * 3 + pow
			return
		
		moves[length] = cur_move
		length += 1
	
	func to_str() -> String:
		var buf = ""
		var urf = (urf_idx + 3) % 6 if (verbose & INVERSE_SOLUTION) != 0 else urf_idx
		
		if urf < 3:
			for s in range(length):
				if (verbose & USE_SEPARATOR) != 0 and s == depth1:
					buf += ".  "
				buf += Min2Phase.MOVE2STR[Min2Phase.URF_MOVE[urf][moves[s]]].strip_edges() + " "
		else:
			for s in range(length - 1, -1, -1):
				buf += Min2Phase.MOVE2STR[Min2Phase.URF_MOVE[urf][moves[s]]].strip_edges() + " "
				if (verbose & USE_SEPARATOR) != 0 and s == depth1:
					buf += ".  "
		
		if (verbose & APPEND_LENGTH) != 0:
			buf += "(" + str(length) + "f)"
		
		return buf.strip_edges()

# Helper functions for permutation and combination calculations
static func get_nparity(idx: int, n: int) -> int:
	var p = 0
	var i = n - 2
	while i >= 0:
		p ^= idx % (n - i)
		idx /= n - i
		i -= 1
	return p & 1

static func get_nperm(arr: Array, n: int) -> int:
	var idx = 0
	var val = 0x76543210
	for i in range(n - 1):
		var v = arr[i] << 2
		idx = (n - i) * idx + ((val >> v) & 0xf)
		val -= 0x11111110 << v
	return idx

static func set_nperm(arr: Array, idx: int, n: int):
	var extract = 0
	var val = 0x76543210
	for i in range(2, n + 1):
		extract = (extract << 4) | (idx % i)
		idx /= i
	for i in range(n - 1):
		var v = (extract & 0xf) << 2
		extract >>= 4
		arr[i] = ((val >> v) & 0xf)
		var m = (1 << v) - 1
		val = (val & m) | ((val >> 4) & ~m)
	arr[n - 1] = (val & 0xf)

static func get_comb(arr: Array, n: int, mask: int) -> int:
	var idx_c = 0
	var r = 4
	var cnk = 330 if n == 12 else 35
	for i in range(n - 1, -1, -1):
		if (arr[i] & 0xc) == mask:
			idx_c += cnk
			cnk = cnk * r / max(1, i - r + 1)
			r -= 1
		cnk = cnk * (i - r) / max(1, i)
	return idx_c

static func set_comb(arr: Array, idx_c: int, n: int, mask: int):
	var r = 4
	var fill = n - 1
	var cnk = 330 if n == 12 else 35
	for i in range(n - 1, -1, -1):
		if idx_c >= cnk:
			idx_c -= cnk
			cnk = cnk * r / max(1, i - r + 1)
			r -= 1
			arr[i] = r | mask
		else:
			if (fill & 0xc) == mask:
				fill -= 4
			arr[i] = fill
			fill -= 1
		cnk = cnk * (i - r) / max(1, i)

static func esym2csym(esym: int) -> int:
	return esym ^ ((0x00dddd00 >> ((esym & 0xf) << 1)) & 3)

# IDA context for solving
class IdaContext:
	var mv: PackedByteArray
	var allow_shorter: bool = false
	var depth1: int = 0
	var length1: int = 0
	var valid1: int = 0
	var urf_idx: int = 0
	var p1_cubies: Array[Cubie]
	var urf_cubies: Array[Cubie]
	var premv: PackedByteArray
	var premv_len: int = 0
	var max_depth2: int = 0
	var target_length: int = 0
	var probes: int = 0
	var min_probes: int = 0
	var solution: Solution
	
	func _init():
		mv.resize(30)
		premv.resize(15)
		p1_cubies.resize(20)
		urf_cubies.resize(6)
		for i in range(20):
			p1_cubies[i] = Cubie.new()
		for i in range(6):
			urf_cubies[i] = Cubie.new()
		solution = Solution.new()
	
	func solve_cubie(sctx: StaticContext, stbl: StaticTables, cc: Cubie, target_length: int) -> String:
		var cc1 = cc.clone()
		var cc2 = Cubie.new()
		target_length = target_length + 1
		probes = 0
		
		# Generate URF symmetry variants
		for i in range(6):
			urf_cubies[i].copy_from(cc1)
			Cubie.corn_mult(sctx.symurfi, cc1, cc2)
			Cubie.edge_mult(sctx.symurfi, cc1, cc2)
			Cubie.corn_mult(cc2, sctx.symurf, cc1)
			Cubie.edge_mult(cc2, sctx.symurf, cc1)
			if i == 2:
				Cubie.inv(cc1, cc2)
				cc1.copy_from(cc2)
		
		# Try different phase 1 lengths
		for l1 in range(21):
			length1 = l1
			max_depth2 = min(MAX_DEPTH2, target_length - length1 - 1)
			depth1 = length1 - premv_len
			allow_shorter = false
			
			# Try different URF symmetries
			for j in range(6):
				urf_idx = j
				var cc3 = urf_cubies[urf_idx] # assign the referenece
				var ret = phase1_pre_moves(sctx, stbl, MAX_PREMV_LEN, -30, cc3)
				if ret == 0:
					var solbuf: String = solution.to_str()
					return solbuf
		
		return "Error 8"
	
	func phase1_pre_moves(sctx: StaticContext, stbl: StaticTables, maxl: int, lm: int, cc: Cubie) -> int:
		premv_len = MAX_PREMV_LEN - maxl
		if premv_len == 0 or ((0x667667 >> lm) & 1) == 0:
			depth1 = length1 - premv_len
			allow_shorter = depth1 == MIN_P1PRE_LEN and premv_len != 0
			p1_cubies[0].copy_from(cc)
			var node = Coord.new()
			if node.from_cubie(stbl, p1_cubies[0]) <= depth1:
				var ret = phase1(sctx, stbl, node, 0, depth1, -1)
				if ret == 0:
					return 0
		
		if maxl == 0 or premv_len + MIN_P1PRE_LEN >= length1:
			return 1
		
		var skip_moves = 0
		if maxl == 1 or premv_len + 1 + MIN_P1PRE_LEN >= length1:
			skip_moves = 0x227227
		
		var cd = Cubie.new()
		lm = lm / 3
		
		for m in range(18):
			if m / 3 == lm or m / 3 == lm - 3 or m / 3 == lm + 3:
				continue
			if (skip_moves & (1 << m)) != 0:
				continue
			
			Cubie.corn_mult(sctx.movecube[m], cc, cd)
			Cubie.edge_mult(sctx.movecube[m], cc, cd)
			premv[MAX_PREMV_LEN - maxl] = m
			var ret = phase1_pre_moves(sctx, stbl, maxl - 1, m, cd)
			if ret == 0:
				return 0
		
		return 1
	
	func phase1(sctx: StaticContext, stbl: StaticTables, node: Coord, _ssym: int, maxl: int, lm: int) -> int:
		var next_node = Coord.new()
		
		if node.prun == 0 and maxl < 5:
			if allow_shorter or maxl == 0:
				depth1 -= maxl
				var ret = init_phase2(sctx, stbl)
				depth1 += maxl
				return ret
			else:
				return 1
		
		for axis in range(0, N_MOVES_P1, 3):
			if axis == lm or axis == lm - 9:
				continue
			for power in range(3):
				var m = axis + power
				var prun = next_node.move_prun(sctx, stbl, node, m)
				if prun > maxl:
					break
				elif prun == maxl:
					continue
				
				mv[depth1 - maxl] = m
				valid1 = min(valid1, depth1 - maxl)
				var ret = phase1(sctx, stbl, next_node, 0, maxl - 1, axis)
				if ret == 0:
					return 0
				elif ret >= 2:
					break
		
		return 1
	
	func init_phase2(sctx: StaticContext, stbl: StaticTables) -> int:
		probes += 1
		var cc = p1_cubies[0].clone() if depth1 == 0 else Cubie.new()
		
		for i in range(valid1, depth1):
			Cubie.corn_mult(p1_cubies[i], sctx.movecube[mv[i]], cc)
			Cubie.edge_mult(p1_cubies[i], sctx.movecube[mv[i]], cc)
			p1_cubies[i + 1].copy_from(cc)
		
		valid1 = depth1
		var node1 = Coord2.new()
		var prun = node1.from_cubie(sctx, stbl, cc)
		var node2 = Coord2.new()
		
		if premv_len > 0:
			var m = premv[premv_len - 1] / 3 * 3 + 1
			var cd = Cubie.new()
			Cubie.corn_mult(sctx.movecube[m], cc, cd)
			Cubie.edge_mult(sctx.movecube[m], cc, cd)
			prun = min(prun, node2.from_cubie(sctx, stbl, cd))
		
		if prun > max_depth2:
			return prun - max_depth2
		
		var depth2 = max_depth2
		while depth2 >= prun:
			var sol_src = 0
			var ret = phase2(sctx, stbl, node1, depth2, depth1, 10)
			if ret < 0 and premv_len > 0:
				sol_src = 1
				ret = phase2(sctx, stbl, node2, depth2, depth1, 10)
			if ret < 0:
				break
			
			depth2 -= ret
			target_length = 0
			solution.length = 0
			solution.urf_idx = urf_idx
			solution.depth1 = depth1
			solution.premv_len = premv_len
			
			for i in range(depth1 + depth2):
				solution.append_move(mv[i])
			
			if sol_src == 1:
				solution.append_move(premv[premv_len - 1] / 3 * 3 + 1)
			
			for i in range(premv_len - 1, -1, -1):
				solution.append_move(premv[i])
			
			target_length = solution.length
			depth2 -= 1
		
		if depth2 != max_depth2:
			max_depth2 = min(MAX_DEPTH2, target_length - length1 - 1)
			return 0 if probes >= min_probes else 1
		
		return 1
	
	func phase2(sctx: StaticContext, stbl: StaticTables, node: Coord2, maxl: int, depth: int, lm: int) -> int:
		if node.edge == 0 and node.corn == 0 and node.mid == 0:
			return maxl
		
		var move_mask = sctx.canon_masks2[lm]
		var nodex = Coord2.new()
		
		for m in range(N_MOVES_P2):
			if (move_mask >> m & 1) != 0:
				continue
			
			nodex.mid = stbl.mperm_move[node.mid * N_MOVES_P2 + m]
			nodex.corn = stbl.cperm_move[node.corn * N_MOVES_P2 + sctx.symmove2[m][node.csym]]
			nodex.csym = sctx.symmult[nodex.corn & 0xf][node.csym]
			nodex.corn = nodex.corn >> 4
			nodex.edge = stbl.eperm_move[node.edge * N_MOVES_P2 + sctx.symmove2[m][node.esym]]
			nodex.esym = sctx.symmult[nodex.edge & 0xf][node.esym]
			nodex.edge = nodex.edge >> 4
			
			var edgei = Min2Phase.get_perm_sym_inv(sctx, stbl, nodex.edge, nodex.esym, 0)
			var corni = Min2Phase.get_perm_sym_inv(sctx, stbl, nodex.corn, nodex.csym, 1)
			var prun = Min2Phase.get_pruning(stbl.ccomb_eperm_prun,
				(edgei >> 4) * N_CCOMB +
				stbl.ccomb_conj[stbl.cperm2comb[corni >> 4] * 16 + sctx.symmuli[edgei & 0xf][corni & 0xf]])
			
			if prun > maxl + 1:
				return maxl - prun + 1
			elif prun >= maxl:
				continue
			
			prun = max(
				Min2Phase.get_pruning(stbl.mperm_cperm_prun, nodex.corn * N_MPERM + stbl.mperm_conj[nodex.mid * 16 + nodex.csym]),
				Min2Phase.get_pruning(stbl.ccomb_eperm_prun, nodex.edge * N_CCOMB + stbl.ccomb_conj[stbl.cperm2comb[nodex.corn] * 16 + sctx.symmuli[nodex.esym][nodex.csym]])
			)
			
			if prun >= maxl:
				continue
			
			var ret = phase2(sctx, stbl, nodex, maxl - 1, depth + 1, m)
			if ret >= 0:
				mv[depth] = Min2Phase.P2MOVES[m]
				return ret
			elif ret < -2:
				break
		
		return -1

# Static context for move tables and symmetry
class StaticContext:
	var movecube: Array[Cubie]
	var symcube: Array[Cubie]
	var symmult: Array[Array]
	var symmuli: Array[Array]
	var symmove: Array[Array]
	var symmove2: Array[Array]
	var canon_masks2: PackedInt32Array
	var symurf: Cubie
	var symurfi: Cubie
	
	func _init():
		movecube.resize(18)
		symcube.resize(16)
		symmult.resize(16)
		symmuli.resize(16)
		symmove.resize(18)
		symmove2.resize(18)
		canon_masks2.resize(11)
		
		for i in range(18):
			movecube[i] = Cubie.new()
		for i in range(16):
			symcube[i] = Cubie.new()
			symmult[i] = []
			symmuli[i] = []
			symmult[i].resize(16)
			symmuli[i].resize(16)
		for i in range(18):
			symmove[i] = []
			symmove2[i] = []
			symmove[i].resize(8)
			symmove2[i].resize(16)
		
		symurf = Cubie.new()
		symurfi = Cubie.new()
		init()
	
	func init():
		var movebase = [
			Cubie.new(), Cubie.new(), Cubie.new(), Cubie.new(), Cubie.new(), Cubie.new()
		]
		
		movebase[0].ca = [3, 0, 1, 2, 4, 5, 6, 7]
		movebase[0].ea = [6, 0, 2, 4, 8, 10, 12, 14, 16, 18, 20, 22]
		movebase[1].ca = [20, 1, 2, 8, 15, 5, 6, 19]
		movebase[1].ea = [16, 2, 4, 6, 22, 10, 12, 14, 8, 18, 20, 0]
		movebase[2].ca = [9, 21, 2, 3, 16, 12, 6, 7]
		movebase[2].ea = [0, 19, 4, 6, 8, 17, 12, 14, 3, 11, 20, 22]
		movebase[3].ca = [0, 1, 2, 3, 5, 6, 7, 4]
		movebase[3].ea = [0, 2, 4, 6, 10, 12, 14, 8, 16, 18, 20, 22]
		movebase[4].ca = [0, 10, 22, 3, 4, 17, 13, 7]
		movebase[4].ea = [0, 2, 20, 6, 8, 10, 18, 14, 16, 4, 12, 22]
		movebase[5].ca = [0, 1, 11, 23, 4, 5, 18, 14]
		movebase[5].ea = [0, 2, 4, 23, 8, 10, 12, 21, 16, 18, 7, 15]
		
		# Generate all 18 moves
		for i in range(18):
			if i % 3 == 0:
				movecube[i].copy_from(movebase[i / 3])
			else:
				var cc = Cubie.new()
				Cubie.corn_mult(movecube[i - 1], movebase[i / 3], cc)
				Cubie.edge_mult(movecube[i - 1], movebase[i / 3], cc)
				movecube[i].copy_from(cc)
		
		# Symmetry cubes
		var u4 = Cubie.new()
		u4.ca = [3, 0, 1, 2, 7, 4, 5, 6]
		u4.ea = [6, 0, 2, 4, 14, 8, 10, 12, 23, 17, 19, 21]
		
		var lr2 = Cubie.new()
		lr2.ca = [25, 24, 27, 26, 29, 28, 31, 30]
		lr2.ea = [4, 2, 0, 6, 12, 10, 8, 14, 18, 16, 22, 20]
		
		var f2 = Cubie.new()
		f2.ca = [5, 4, 7, 6, 1, 0, 3, 2]
		f2.ea = [12, 10, 8, 14, 4, 2, 0, 6, 18, 16, 22, 20]
		
		var cc = Cubie.new()
		var cd = Cubie.new()
		
		# Generate symmetry cubes
		for i in range(16):
			symcube[i].copy_from(cc)
			Cubie.corn_mult(cc, u4, cd)
			Cubie.edge_mult(cc, u4, cd)
			cc.copy_from(cd)
			if i % 4 == 3:
				Cubie.corn_mult(cc, lr2, cd)
				Cubie.edge_mult(cc, lr2, cd)
				cc.copy_from(cd)
			if i % 8 == 7:
				Cubie.corn_mult(cc, f2, cd)
				Cubie.edge_mult(cc, f2, cd)
				cc.copy_from(cd)
		
		# URF symmetry
		symurf.ca = [8, 20, 13, 17, 19, 15, 22, 10]
		symurf.ea = [3, 16, 11, 18, 7, 22, 15, 20, 1, 9, 13, 5]
		Cubie.corn_mult(symurf, symurf, symurfi)
		Cubie.edge_mult(symurf, symurf, symurfi)
		
		# Symmetry multiplication tables
		for i in range(16):
			for j in range(16):
				Cubie.corn_mult(symcube[i], symcube[j], cc)
				Cubie.edge_mult(symcube[i], symcube[j], cc)
				for k in range(16):
					if cc.cmp(symcube[k]) == 0:
						symmult[i][j] = k
						symmuli[k][j] = i
		
		# P2MOVES inverse mapping
		var p2moves_imap = []
		p2moves_imap.resize(18)
		for i in range(18):
			p2moves_imap[Min2Phase.P2MOVES[i]] = i
		
		# Symmetry move tables
		for i in range(18):
			for j in range(16):
				Cubie.corn_mult(symcube[j], movecube[i], cc)
				Cubie.corn_mult(cc, symcube[symmuli[0][j]], cd)
				Cubie.edge_mult(symcube[j], movecube[i], cc)
				Cubie.edge_mult(cc, symcube[symmuli[0][j]], cd)
				for k in range(18):
					if movecube[k].cmp(cd) == 0:
						symmove2[p2moves_imap[i]][j] = p2moves_imap[k]
						if j % 2 == 0:
							symmove[i][j / 2] = k
						break
		
		# Canonical masks for phase 2
		for i in range(10):
			var ix = Min2Phase.P2MOVES[i] / 3
			canon_masks2[i] = 0
			for j in range(10):
				var jx = Min2Phase.P2MOVES[j] / 3
				canon_masks2[i] |= (1 if (ix == jx) or ((ix % 3 == jx % 3) and (ix >= jx)) else 0) << j
		canon_masks2[10] = 0

# Static tables for pruning and move lookups
class StaticTables:
	var perm_sym_inv: PackedInt32Array
	var cperm2comb: PackedByteArray
	var flip_sym2raw: PackedInt32Array
	var flip_raw2sym: PackedInt32Array
	var flip_selfsym: PackedInt32Array
	var twst_sym2raw: PackedInt32Array
	var twst_raw2sym: PackedInt32Array
	var twst_selfsym: PackedInt32Array
	var eperm_sym2raw: PackedInt32Array
	var eperm_raw2sym: PackedInt32Array
	var eperm_selfsym: PackedInt32Array
	var flip_move: PackedInt32Array
	var twst_move: PackedInt32Array
	var slice_move: PackedInt32Array
	var slice_conj: PackedInt32Array
	var cperm_move: PackedInt32Array
	var eperm_move: PackedInt32Array
	var mperm_move: PackedInt32Array
	var mperm_conj: PackedInt32Array
	var ccomb_move: PackedInt32Array
	var ccomb_conj: PackedInt32Array
	var slice_flip_prun: PackedInt32Array
	var slice_twst_prun: PackedInt32Array
	var ccomb_eperm_prun: PackedInt32Array
	var mperm_cperm_prun: PackedInt32Array
	
	func _init(sctx: StaticContext):
		perm_sym_inv.resize(N_PERM_SYM)
		cperm2comb.resize(N_PERM_SYM)
		flip_sym2raw.resize(N_FLIP_SYM)
		flip_raw2sym.resize(N_FLIP)
		flip_selfsym.resize(N_FLIP_SYM)
		twst_sym2raw.resize(N_TWST_SYM)
		twst_raw2sym.resize(N_TWST)
		twst_selfsym.resize(N_TWST_SYM)
		eperm_sym2raw.resize(N_PERM_SYM)
		eperm_raw2sym.resize(N_PERM)
		eperm_selfsym.resize(N_PERM_SYM)
		flip_move.resize(N_FLIP_SYM * N_MOVES_P1)
		twst_move.resize(N_TWST_SYM * N_MOVES_P1)
		slice_move.resize(N_SLICE * N_MOVES_P1)
		slice_conj.resize(N_SLICE * 8)
		cperm_move.resize(N_PERM_SYM * N_MOVES_P2)
		eperm_move.resize(N_PERM_SYM * N_MOVES_P2)
		mperm_move.resize(N_MPERM * N_MOVES_P2)
		mperm_conj.resize(N_MPERM * 16)
		ccomb_move.resize(N_CCOMB * N_MOVES_P2)
		ccomb_conj.resize(N_CCOMB * 16)
		slice_flip_prun.resize(N_SLICE * N_FLIP_SYM / 8 + 1)
		slice_twst_prun.resize(N_SLICE * N_TWST_SYM / 8 + 1)
		ccomb_eperm_prun.resize(N_CCOMB * N_PERM_SYM / 8 + 1)
		mperm_cperm_prun.resize(N_MPERM * N_PERM_SYM / 8 + 1)

		init(sctx)
	
	func init(sctx: StaticContext):
		var start_time = Time.get_ticks_msec()
		Min2Phase.init_sym2raw(sctx, N_FLIP, 0, flip_sym2raw, flip_raw2sym, flip_selfsym)
		var end_time = Time.get_ticks_msec() - start_time
		print("#1 init_sym2raw call time: ", end_time)
		
		start_time = Time.get_ticks_msec()
		Min2Phase.init_sym2raw(sctx, N_TWST, 1, twst_sym2raw, twst_raw2sym, twst_selfsym)
		end_time = Time.get_ticks_msec() - start_time
		print("#2 init_sym2raw call time: ", end_time)

		start_time = Time.get_ticks_msec()
		Min2Phase.init_sym2raw(sctx, N_PERM, 2, eperm_sym2raw, eperm_raw2sym, eperm_selfsym)
		end_time = Time.get_ticks_msec() - start_time
		print("#3 init_sym2raw call time: ", end_time)
		
		start_time = Time.get_ticks_msec()
		Min2Phase.init_move_tables(sctx, self)
		end_time = Time.get_ticks_msec() - start_time
		print("init_move_table call time: ", end_time)

		start_time = Time.get_ticks_msec()
		Min2Phase.init_raw_sym_prun(slice_twst_prun, slice_move, slice_conj, twst_move, twst_selfsym, N_SLICE, N_TWST_SYM, 0x69603)
		end_time = Time.get_ticks_msec() - start_time
		print("#1 init_raw_sym_prun call time: ", end_time)

		start_time = Time.get_ticks_msec()
		Min2Phase.init_raw_sym_prun(slice_flip_prun, slice_move, slice_conj, flip_move, flip_selfsym, N_SLICE, N_FLIP_SYM, 0x69603)
		end_time = Time.get_ticks_msec() - start_time
		print("#2 init_raw_sym_prun call time: ", end_time)

		start_time = Time.get_ticks_msec()
		Min2Phase.init_raw_sym_prun(ccomb_eperm_prun, ccomb_move, ccomb_conj, eperm_move, eperm_selfsym, N_CCOMB, N_PERM_SYM, 0x7c824)
		end_time = Time.get_ticks_msec() - start_time
		print("#3 init_raw_sym_prun call time: ", end_time)

		start_time = Time.get_ticks_msec()
		Min2Phase.init_raw_sym_prun(mperm_cperm_prun, mperm_move, mperm_conj, cperm_move, eperm_selfsym, N_MPERM, N_PERM_SYM, 0x8ea34)
		end_time = Time.get_ticks_msec() - start_time
		print("#4 init_raw_sym_prun call time: ", end_time)

# Functions for initializing move tables and pruning tables
static func init_sym2raw(sctx: StaticContext, n_raw: int, coord: int, sym2raw: PackedInt32Array, raw2sym: PackedInt32Array, selfsym: PackedInt32Array) -> int:
	var c = Cubie.new()
	var e = Cubie.new()
	var d = Cubie.new()
	var sym_inc = 1 if coord >= 2 else 2
	var sym_shift = 0 if coord >= 2 else 1
	
	for i in range(n_raw):
		raw2sym[i] = 0
	
	var count = 0
	for i in range(n_raw):
		if raw2sym[i] as int != 0:
			continue
		
		match coord:
			0: c.set_flip(i)
			1: c.set_twst(i)
			2: c.set_eperm(i)
			_: push_error("Invalid coordinate: coord=", coord)
		
		for s in range(0, 16, sym_inc):
			if coord == 1:
				Cubie.corn_mult(sctx.symcube[sctx.symmuli[0][s]], c, e)
				Cubie.corn_mult(e, sctx.symcube[s], d)
			else:
				Cubie.edge_mult(sctx.symcube[sctx.symmuli[0][s]], c, e)
				Cubie.edge_mult(e, sctx.symcube[s], d)
			
			var idx
			match coord:
				0: idx = d.get_flip()
				1: idx = d.get_twst()
				2: idx = d.get_eperm()
			
			if idx == i:
				selfsym[count] |= 1 << (s >> sym_shift)
			raw2sym[idx] = ((count << 4 | s) >> sym_shift)
		
		sym2raw[count] = i
		count += 1
	
	return count

static func init_move_tables(sctx: StaticContext, stbl: StaticTables):
	var c = Cubie.new()
	c.reset()
	
	# Flip move table
	for i in range(N_FLIP_SYM):
		c.set_flip(stbl.flip_sym2raw[i])
		for j in range(N_MOVES_P1):
			var d = Cubie.new()
			Cubie.edge_mult(c, sctx.movecube[j], d)
			stbl.flip_move[i * N_MOVES_P1 + j] = stbl.flip_raw2sym[d.get_flip()]
	
	# Twist move table
	for i in range(N_TWST_SYM):
		c.set_twst(stbl.twst_sym2raw[i])
		for j in range(N_MOVES_P1):
			var d = Cubie.new()
			Cubie.corn_mult(c, sctx.movecube[j], d)
			stbl.twst_move[i * N_MOVES_P1 + j] = stbl.twst_raw2sym[d.get_twst()]
	
	# Slice move and conjugate tables
	for i in range(N_SLICE):
		c.set_slice(i)
		for j in range(N_MOVES_P1):
			var d = Cubie.new()
			Cubie.edge_mult(c, sctx.movecube[j], d)
			stbl.slice_move[i * N_MOVES_P1 + j] = d.get_slice()
		
		for j in range(8):
			var e = Cubie.new()
			var d = Cubie.new()
			Cubie.edge_mult(sctx.symcube[j << 1], c, e)
			Cubie.edge_mult(e, sctx.symcube[j << 1], d)
			stbl.slice_conj[i * 8 + j] = d.get_slice()
	
	# Phase 2 move tables
	c.reset()
	for i in range(N_PERM_SYM):
		c.set_cperm(stbl.eperm_sym2raw[i])
		c.set_eperm(stbl.eperm_sym2raw[i])
		for j in range(N_MOVES_P2):
			var d = Cubie.new()
			Cubie.corn_mult(c, sctx.movecube[P2MOVES[j]], d)
			Cubie.edge_mult(c, sctx.movecube[P2MOVES[j]], d)
			stbl.cperm_move[i * N_MOVES_P2 + j] = esym2csym(stbl.eperm_raw2sym[d.get_cperm()])
			stbl.eperm_move[i * N_MOVES_P2 + j] = stbl.eperm_raw2sym[d.get_eperm()]
		
		var d = Cubie.new()
		Cubie.inv(c, d)
		stbl.perm_sym_inv[i] = stbl.eperm_raw2sym[d.get_eperm()]
		stbl.cperm2comb[i] = c.get_ccomb()
	
	# M-perm move and conjugate tables
	for i in range(N_MPERM):
		c.set_mperm(i)
		for j in range(N_MOVES_P2):
			var d = Cubie.new()
			Cubie.edge_mult(c, sctx.movecube[P2MOVES[j]], d)
			stbl.mperm_move[i * N_MOVES_P2 + j] = d.get_mperm()
		
		for j in range(16):
			var e = Cubie.new()
			var d = Cubie.new()
			Cubie.edge_mult(sctx.symcube[j], c, e)
			Cubie.edge_mult(e, sctx.symcube[sctx.symmuli[0][j]], d)
			stbl.mperm_conj[i * 16 + j] = d.get_mperm()
	
	# C-comb move and conjugate tables
	for i in range(N_CCOMB):
		c.set_ccomb(i)
		for j in range(N_MOVES_P2):
			var d = Cubie.new()
			Cubie.corn_mult(c, sctx.movecube[P2MOVES[j]], d)
			stbl.ccomb_move[i * N_MOVES_P2 + j] = d.get_ccomb()
		
		for j in range(16):
			var e = Cubie.new()
			var d = Cubie.new()
			Cubie.corn_mult(sctx.symcube[j], c, e)
			Cubie.corn_mult(e, sctx.symcube[sctx.symmuli[0][j]], d)
			stbl.ccomb_conj[i * 16 + j] = d.get_ccomb()

static func set_pruning(table: PackedInt32Array, index: int, value: int):
	table[index >> 3] ^= value << ((index & 7) << 2)

static func get_pruning(table: PackedInt32Array, index: int) -> int:
	return (table[index >> 3] >> ((index & 7) << 2)) & 0xf

static func init_raw_sym_prun(prun_table: PackedInt32Array, raw_move: PackedInt32Array, raw_conj: PackedInt32Array, sym_move: PackedInt32Array, sym_selfsym: PackedInt32Array, n_raw: int, n_sym: int, prun_flag: int):
	var sym_shift = prun_flag & 0xf
	var sym_e2c_magic = 0x00DDDD00 if (prun_flag >> 4) & 1 == 1 else 0
	var is_phase2 = 1 if (prun_flag >> 5) & 1 == 1 else 0
	var inv_depth = (prun_flag >> 8) & 0xf
	var max_depth = (prun_flag >> 12) & 0xf
	
	var sym_mask = (1 << sym_shift) - 1
	var n_entries = n_raw * n_sym
	var n_moves = N_MOVES_P2 if is_phase2 != 0 else N_MOVES_P1
	
	var depth = 0
	
	for i in range(n_entries / 8 + 1):
		prun_table[i] = 0xffffffff
	Min2Phase.set_pruning(prun_table, 0, 0xf)
	
	while depth < max_depth:
		var inv = depth > inv_depth
		var select = 0xf if inv else depth
		var check = depth if inv else 0xf
		depth += 1
		var xor_val = depth ^ 0xf
		var val = 0
		var i = 0
		
		while i < n_entries:
			if (i & 7) == 0:
				val = prun_table[i >> 3]
				if not inv and val == 0xffffffff:
					i += 8
					continue
			
			if (val & 0xf) != select:
				i += 1
				val >>= 4
				continue
			
			var raw: int = i % n_raw
			var sym: int = i / n_raw
			
			for m in range(n_moves):
				var symx = sym_move[sym * n_moves + m]
				var rawx = raw_conj[raw_move[raw * n_moves + m] << sym_shift | (symx & sym_mask)]
				symx = symx >> sym_shift
				var idx = symx * n_raw + rawx
				var prun = get_pruning(prun_table, idx)
				
				if prun != check:
					continue
				
				if inv:
					set_pruning(prun_table, i, xor_val)
					break
				
				set_pruning(prun_table, idx, xor_val)
				idx = idx - rawx
				
				for j in range(1, 16):
					var ssmask = sym_selfsym[symx]
					if (ssmask >> j) & 1 == 0:
						continue
					var idxx = idx + raw_conj[((rawx << sym_shift) | (j ^ (sym_e2c_magic >> (j << 1) & 3)))]
					if get_pruning(prun_table, idxx) == check:
						set_pruning(prun_table, idxx, xor_val)
			
			i += 1
			val >>= 4

static func get_perm_sym_inv(sctx: StaticContext, stbl: StaticTables, idx: int, sym: int, is_corner: int) -> int:
	var idxi = stbl.perm_sym_inv[idx]
	var result = esym2csym(idxi) if is_corner != 0 else idxi
	result = (result & 0xfff0) | sctx.symmult[result & 0xf][sym]
	return result

# Global static instances
var global_sctx: StaticContext
var global_stbl: StaticTables

func _ready():
	# Initialize global static instances
	var start_time = Time.get_ticks_msec()
	global_sctx = StaticContext.new()
	var end_time = Time.get_ticks_msec() - start_time
	print("Global sctx initialization time: ", end_time)

	start_time = Time.get_ticks_msec()
	global_stbl = StaticTables.new(global_sctx)
	end_time = Time.get_ticks_msec() - start_time
	print("Static tables initialization time: ", end_time)

# Main solve function
# Solve a Rubik's cube represented in facelet
#
# Arguments:
# - facelet: the Rubik's cube to be solved, represented in facelet
# - maxl: number of moves to solve the cube, included. 21 or 20 is recommended.
#
# Facelet for the rubik's cube:
# ```
#          +--------+
#          |U1 U2 U3|
#          |U4 U5 U6|
#          |U7 U8 U9|
# +--------+--------+--------+--------+
# |L1 L2 L3|F1 F2 F3|R1 R2 R3|B1 B2 B3|
# |L4 L5 L6|F4 F5 F6|R4 R5 R6|B4 B5 B6|
# |L7 L8 L9|F7 F8 F9|R7 R8 R9|B7 B8 B9|
# +--------+--------+--------+--------+
#          |D1 D2 D3|
#          |D4 D5 D6|
#          |D7 D8 D9|
#          +--------+
# ```
# should be: U1U2...U9R1R2...R9F1..F9D1..D9L1..L9B1..B9
# Example, facelet of solved cube is UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB
#
# Return solution moves on success, return "Error " + error_code on failure
func solve(facelet: String, maxl: int = 21) -> String:
	var cc = Cubie.new()
	if cc.from_facelet(facelet) < 0:
		return "Error 1"
	
	var verify = cc.verify()
	if verify < 0:
		return "Error " + str(-verify)
	
	var ctx = IdaContext.new()
	return ctx.solve_cubie(global_sctx, global_stbl, cc, min(25, maxl))

# Generate a random cube represented in facelet
func random_cube() -> String:
	var cc = Cubie.new()
	cc.random_reset()
	return cc.to_facelet()

# Apply moves to a solved Rubik's cube
#
# Arguments:
# - cube_moves: should match pattern ([URFDLB][123'] ?)*
#
# Return facelet on success
func from_moves(cube_moves: String) -> String:
	return apply_moves(SOLVED_CUBE, cube_moves)

# Apply moves to a Rubik's cube represented by facelet
#
# Arguments:
# - facelet: the Rubik's cube to be moved, must be a solvable Rubik's cube
# - cube_moves: should match pattern ([URFDLB][123'] ?)*
#
# Return facelet of the moved cube on success
func apply_moves(facelet: String, cube_moves: String) -> String:
	var cc = Cubie.new()
	if cc.from_facelet(facelet) < 0:
		return ""
	
	var verify = cc.verify()
	if verify < 0:
		return ""
	
	var s = cube_moves.strip_edges()
	var axis = 0
	var pow = 0
	var cd = Cubie.new()
	
	for i in range(s.length()):
		var c = s[i]
		match c:
			'U', 'R', 'F', 'D', 'L', 'B':
				if pow != 0:
					Cubie.corn_mult(cc, global_sctx.movecube[axis * 3 + pow - 1], cd)
					Cubie.edge_mult(cc, global_sctx.movecube[axis * 3 + pow - 1], cd)
					cc.copy_from(cd)
				pow = 1
				match c:
					'U': axis = 0
					'R': axis = 1
					'F': axis = 2
					'D': axis = 3
					'L': axis = 4
					'B': axis = 5
			'\'', '-': pow = (4 - pow) % 4
			'3': pow = pow * 3 % 4
			'2': pow = pow * 2 % 4
			'+', '1', ' ', '\t': pass
			_: return ""
	
	if pow != 0:
		Cubie.corn_mult(cc, global_sctx.movecube[axis * 3 + pow - 1], cd)
		Cubie.edge_mult(cc, global_sctx.movecube[axis * 3 + pow - 1], cd)
		cc.copy_from(cd)
	
	return cc.to_facelet()

# Generate a random move sequence in specific number of moves
#
# Arguments:
# - n_moves: number of moves
#
# Return moves, ensure no redaudant moves exists, e.g. "R R", "R L R", etc.
#
# Call from_moves(moves) to obtain the scrambled cube
func random_moves(n_moves: int) -> String:
	var last_axis = 18
	var scramble = ""
	var i = 0
	
	while i < n_moves:
		var mv = randi() % 18
		var axis = mv / 3
		if axis == last_axis or (axis % 3 == last_axis % 3 and axis > last_axis):
			continue
		last_axis = axis
		scramble += MOVE2STR[mv].strip_edges() + " "
		i += 1
	
	return scramble.strip_edges()
