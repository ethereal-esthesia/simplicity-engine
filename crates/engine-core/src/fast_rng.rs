pub struct FastRng {
    state: u64,
    bit_buffer: u64,
    bits_left: u8,
    cache16: u64,
    left16: u8,
    cache32: u64,
    left32: u8,
    cache_bool: u64,
    left_bool: u8,
}

impl FastRng {
    pub fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 { 0x9E3779B97F4A7C15 } else { seed },
            bit_buffer: 0,
            bits_left: 0,
            cache16: 0,
            left16: 0,
            cache32: 0,
            left32: 0,
            cache_bool: 0,
            left_bool: 0,
        }
    }

    pub fn next_bits(&mut self, bits: u8) -> u64 {
        assert!((1..=64).contains(&bits), "bits must be in 1..=64");
        let mut remaining = bits;
        let mut out = 0;

        while remaining > 0 {
            if self.bits_left == 0 {
                self.bit_buffer = self.next_word64();
                self.bits_left = 64;
            }

            let take = remaining.min(self.bits_left);
            let shift = self.bits_left - take;
            let chunk = (self.bit_buffer >> shift) & Self::mask_low_bits(take);

            out = if take == 64 {
                chunk
            } else {
                (out << take) | chunk
            };

            self.bits_left -= take;
            remaining -= take;
        }

        out
    }

    pub fn next_u16(&mut self) -> u16 {
        if self.left16 == 0 {
            self.cache16 = self.next_word64();
            self.left16 = 4;
        }
        let shift = (self.left16 - 1) * 16;
        self.left16 -= 1;
        ((self.cache16 >> shift) & 0xFFFF) as u16
    }

    pub fn next_u32(&mut self) -> u32 {
        if self.left32 == 0 {
            self.cache32 = self.next_word64();
            self.left32 = 2;
        }
        let shift = (self.left32 - 1) * 32;
        self.left32 -= 1;
        ((self.cache32 >> shift) & 0xFFFF_FFFF) as u32
    }

    pub fn next_u64(&mut self) -> u64 {
        self.next_bits(64)
    }

    pub fn next_bool(&mut self) -> bool {
        if self.left_bool == 0 {
            self.cache_bool = self.next_word64();
            self.left_bool = 64;
        }
        let bit = self.cache_bool >> 63 != 0;
        self.cache_bool <<= 1;
        self.left_bool -= 1;
        bit
    }

    pub fn state(&self) -> u64 {
        self.state
    }

    fn mask_low_bits(bits: u8) -> u64 {
        if bits == 64 {
            u64::MAX
        } else {
            (1u64 << bits) - 1
        }
    }

    fn next_word64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.state = x;
        x.wrapping_mul(0x2545F4914F6CDD1D)
    }
}

#[cfg(test)]
mod tests {
    use super::FastRng;

    fn collect<T, const N: usize>(mut next: impl FnMut() -> T) -> [T; N] {
        std::array::from_fn(|_| next())
    }

    #[test]
    fn u16_seed_one_matches_golden_vector() {
        let mut rng = FastRng::new(1);
        assert_eq!(
            collect(|| rng.next_u16()),
            [
                18404, 52811, 35180, 56605, 43983, 42664, 57465, 25885, 47569, 3471, 60275, 8023,
                19892, 6304, 47899, 413, 3681, 39344, 19802, 42496, 51303, 19403, 17123, 43737,
                53330, 45784, 54382, 29057, 44145, 36088, 52785, 14733, 22194, 45346, 59720, 12344,
                49146, 45624, 16973, 14997, 32691, 14449, 24252, 11486, 11603, 26223, 36059, 47772,
                10150, 49393, 20433, 21008, 48245, 11760, 49829, 39679, 57329, 51528, 60514, 7777,
                41449, 14843, 37518, 3633, 12061, 42500, 45627, 98, 5636, 24438, 12419, 1714,
                33006, 9254, 35214, 20904, 58132, 49549, 38433, 10945, 31231, 49122, 23436, 64919,
                20190, 12397, 43439, 9297, 43775, 28227, 33634, 11162, 6471, 61276, 8051, 25704,
                13198, 6107, 2383, 62298,
            ]
        );
    }

    #[test]
    fn u32_seed_one_matches_golden_vector() {
        let mut rng = FastRng::new(1);
        assert_eq!(
            collect(|| rng.next_u32()),
            [
                1206177355, 2305613085, 2882512552, 3766052125, 3117485455, 3950190423, 1303648416,
                3139109277, 241277360, 1297786368, 3362212811, 1122216665, 3495080664, 3564007809,
                2893122808, 3459332493, 1454551330, 3913822264, 3220877880, 1112357525, 2142451825,
                1589390558, 760440431, 2363210396, 665239793, 1339118096, 3161796080, 3265633023,
                3757164872, 3965853281, 2716416507, 2458783281, 790472196, 2990211170, 369385334,
                813893298, 2163090470, 2307805608, 3809788301, 2518756033, 2046803938, 1535966615,
                1323184237, 2846827601, 2868866627, 2204248986, 424144732, 527656040, 864950235,
                156234586, 3629865355, 1896183576, 2259644924, 1800129870, 3802126848, 4344695,
                1624164765, 57283470, 1196917027, 1644184286, 1200209218, 3500219380, 1433451912,
                24606094, 3937712542, 2952623507, 1144922877, 2111727739, 1252007992, 2026824914,
                154181161, 1818716517, 30745847, 505539047, 1420417193, 1960973545, 2318660238,
                1208575440, 1593341701, 2483401811, 3234753069, 2859289403, 1055613557, 1816760021,
                2445364992, 2793786888, 3376974990, 3349542603, 1719368924, 1721014145, 1181879744,
                1203818629, 3614340549, 994169933, 2386603773, 2337734414, 4212058701, 1125617168,
                3571637491, 2723598058,
            ]
        );
    }

    #[test]
    fn u64_seed_one_matches_golden_vector() {
        let mut rng = FastRng::new(1);
        assert_eq!(
            collect(|| rng.next_u64()),
            [
                5180492295206395165,
                12380297144915551517,
                13389498078930870103,
                5599127315341312413,
                1036278371763004928,
                14440594066559445721,
                15011257152325972353,
                12425867847131019661,
                6247250396617125944,
                13833565160122170005,
                9201760523219905758,
                3266066784064354972,
                2857183156271927824,
                13579810763486632703,
                16136900254885879393,
                11666920062338338353,
                3395052233207513186,
                1586497929965930162,
                9290402829247074728,
                16362916159997160129,
                8790955976569978263,
                5683033027344540753,
                12321688341755079578,
                1821687753238340712,
                3714932972148749146,
                15590152990504613656,
                9705101050952535374,
                16330010467407907703,
                6975734549047808910,
                5140719488634733278,
                5154859343167953908,
                6156629082453276046,
            ]
        );
    }

    #[test]
    fn bool_seed_one_matches_golden_vector() {
        let mut rng = FastRng::new(1);
        assert_eq!(
            collect(|| rng.next_bool()),
            [
                false, true, false, false, false, true, true, true, true, true, true, false, false,
                true, false, false, true, true, false, false, true, true, true, false, false, true,
                false, false, true, false, true, true, true, false, false, false, true, false,
                false, true, false, true, true, false, true, true, false, false, true, true, false,
                true, true, true, false, true, false, false, false, true, true, true, false, true,
                true, false, true, false, true, false, true, true, true, true, false, false, true,
                true, true, true, true, false, true, false, false, true, true, false, true, false,
                true, false, true, false, false, false, true, true, true, false,
            ]
        );
    }

    #[test]
    fn mixed_bit_and_word_reads_preserve_the_stream() {
        let mut rng = FastRng::new(1);
        assert_eq!(rng.next_bits(1), 0);
        assert_eq!(rng.next_bits(15), 0x47E4);
        assert_eq!(rng.next_u16(), 0xABCF);
    }

    #[test]
    fn zero_seed_is_remapped_and_distinct_seeds_diverge() {
        let mut zero_seed = FastRng::new(0);
        assert_ne!(zero_seed.state(), 0);
        assert_ne!(zero_seed.next_u16(), zero_seed.next_u16());

        let mut first = FastRng::new(1);
        let mut second = FastRng::new(2);
        assert!((0..64).any(|_| first.next_u16() != second.next_u16()));
    }

    #[test]
    #[should_panic(expected = "bits must be in 1..=64")]
    fn rejects_zero_bit_reads() {
        FastRng::new(1).next_bits(0);
    }
}
