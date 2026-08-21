import 'package:faker/faker.dart';

/// The seed the fake data of the tests is generated from.
///
/// It is fixed so a test which fails on a fake value fails the same way when it
/// is run again; pass another one to [fakerWithSeed] when a test wants data of
/// its own.
const int defaultFakerSeed = 20240101;

/// The generator the tests use.
final Faker testFaker = fakerWithSeed(defaultFakerSeed);

Faker fakerWithSeed(int seed) {
  return Faker.withGenerator(RandomGenerator(seed: seed));
}
