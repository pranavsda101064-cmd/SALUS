"""Verhoeff checksum used by Aadhaar numbers.

Aadhaar is a 12 digit number whose last digit is a Verhoeff check digit.
The first digit must be between 2 and 9. These tables are public.
"""

D = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
]

P = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 7, 8, 6, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
]

INV = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9]

AADHAAR_LENGTH = 12


def digits_only(value: str) -> str:
    return "".join(ch for ch in str(value) if ch.isdigit())


def validate(number: str) -> bool:
    digits = digits_only(number)
    if not digits:
        return False
    checksum = 0
    for index, char in enumerate(reversed(digits)):
        checksum = D[checksum][P[index % 8][int(char)]]
    return checksum == 0


def generate_check_digit(prefix_digits: str) -> str:
    checksum = 0
    for index, char in enumerate(reversed(prefix_digits)):
        checksum = D[checksum][P[(index + 1) % 8][int(char)]]
    return str(INV[checksum])


def is_valid_aadhaar(value: str) -> bool:
    digits = digits_only(value)
    if len(digits) != AADHAAR_LENGTH:
        return False
    if digits[0] in {"0", "1"}:
        return False
    return validate(digits)
