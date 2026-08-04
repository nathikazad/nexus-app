enum CardRating { again, hard, good, easy }

extension CardRatingValue on CardRating {
  int get fsrsValue => index + 1;
}
