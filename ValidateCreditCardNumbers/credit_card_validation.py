import re

def validate_credit_card(card_number):
    # Match the credit card number with the pattern
    # ^[456] : Must start with 4, 5 or 6
    # \d{3} : Followed by three digits
    # (-?\d{4}){3}$ : Ends with three sets of four digits separated by optional hyphen "-"
    if re.match(r'^[456]\d{3}(-?\d{4}){3}$', card_number):
        # Remove hyphens from the card number
        card_number = card_number.replace("-", "")
        # Check if the card number has four or more consecutive repeated digits
        # \1{3} : Repeated same digit (\1 refers to the same digit) three more times (total four times)
        if not re.search(r'(\d)\1{3}', card_number):
            return 'Valid'
    
    return 'Invalid'

try:
    # Read the number of card numbers
    num_cards = int(input())
    if num_cards < 1 or num_cards > 100:
        raise ValueError("Number of credit cards should be between 1 and 100.")
    for _ in range(num_cards):
        # Read the card number
        card_number = input().strip()
        if len(card_number.replace("-", "")) != 16:
            raise ValueError("Card number should have exactly 16 digits.")
        print(validate_credit_card(card_number))
except ValueError as e:
    print(e)
