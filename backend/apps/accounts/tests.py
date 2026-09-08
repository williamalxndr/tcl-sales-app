from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.test import TestCase


class UserTests(TestCase):
    def test_identity_normalization_and_password_hashing(self):
        user = get_user_model().objects.create_user(
            " Rizky@EXAMPLE.com ", "a-test-password-for-this-suite", employee_number=" B001 "
        )
        user.refresh_from_db()
        self.assertEqual(user.email, "rizky@example.com")
        self.assertEqual(user.employee_number, "B001")
        self.assertTrue(user.id.startswith("usr_"))
        self.assertTrue(user.check_password("a-test-password-for-this-suite"))
        self.assertTrue(user.password.startswith("argon2$"))

    def test_mysql_rejects_duplicate_employee_identity(self):
        users = get_user_model().objects
        users.create_user("first@example.com", employee_number="B001")
        with self.assertRaises(IntegrityError), transaction.atomic():
            users.create_user("second@example.com", employee_number="B001")

    def test_unprovisioned_accounts_do_not_collide_on_empty_employee_number(self):
        users = get_user_model().objects
        first = users.create_user("first@example.com", employee_number="")
        second = users.create_user("second@example.com")
        self.assertIsNone(first.employee_number)
        self.assertIsNone(second.employee_number)
        self.assertFalse(first.has_usable_password())
