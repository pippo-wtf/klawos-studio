import unittest
from klawos_device.user_messages import user_message
class UserMessageTests(unittest.TestCase):
    def test_conflict_explains_next_step_without_internal_paths(self):
        message=user_message(ValueError('Conflicting device edits: hardware.layout.0.0.0'))
        self.assertIn('Export',message);self.assertNotIn('hardware.layout',message)
    def test_unexpected_errors_do_not_expose_details(self):
        for error in [ValueError('/private/secret/path'),RuntimeError('secret-token')]:
            self.assertNotIn('secret',user_message(error));self.assertIn('try again',user_message(error))
    def test_capacity_and_permissions_are_distinct(self):
        self.assertIn('Shorten',user_message(ValueError('Macro buffer exceeds device')))
        self.assertIn('Keyboard lock',user_message(ValueError('Unlock the keyboard in Security before saving macros')))
