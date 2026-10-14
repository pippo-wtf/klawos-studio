import unittest
from klawos_device.keycodes import decode_keycode, encode_keycode

class KeycodeTests(unittest.TestCase):
    def test_vial5_roundtrip_all_uint16(self):
        for value in range(65536):
            self.assertEqual(encode_keycode(decode_keycode(value, 5), 5), value, value)
    def test_vial5_layers_and_modifiers(self):
        self.assertEqual(encode_keycode('TO(1)', 5), 0x5011)
        self.assertEqual(encode_keycode('LCTL(LSFT(KC_A))', 5), 0x0304)
        self.assertEqual(encode_keycode('KC_WH_U', 5), 0x00F9)
    def test_rejects_executable_or_unbounded_expressions(self):
        for value in ["__import__('os').system('echo bad')", 'KC_A.__class__', '[KC_A]', '1 << 99999', '2 ** 99999', 'True', '65536', '-1']:
            with self.subTest(value=value), self.assertRaises(ValueError): encode_keycode(value, 5)
    def test_unknown_numeric_preserved(self):
        self.assertEqual(encode_keycode(65535, 5), 65535)
        with self.assertRaises(ValueError): decode_keycode(4, 99)
