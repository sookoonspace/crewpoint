/**
 * Deterministic load fixtures (Req 60): the same groups and people every
 * run. 400 people make 108 groups, as the app's `scaleFamilies()` in
 * `test_acceptance/seed.dart` does, and the 2,000 tier follows the same
 * pattern.
 */

/** Group sizes repeat this pattern; the last group takes what is left. */
const PATTERN = [4, 3, 7, 1, 5, 2, 4];
const DIETS = ['Veg', 'Jain', 'Non-veg'];

export interface LoadPerson {
  externalId: string;
  group: string;
  name: string;
  age: number;
  diet: string;
  kids: boolean;
}

export interface LoadTier {
  groups: number[];
  people: LoadPerson[];
}

/** Group sizes adding up to [people]. */
export function groupSizes(people: number): number[] {
  const sizes: number[] = [];
  let total = 0;
  for (let i = 0; ; i++) {
    const size = PATTERN[i % PATTERN.length];
    if (total + size >= people) break;
    sizes.push(size);
    total += size;
  }
  sizes.push(people - total);
  return sizes;
}

export function loadTier(people: number): LoadTier {
  const groups = groupSizes(people);
  const out: LoadPerson[] = [];
  groups.forEach((size, g) => {
    for (let i = 0; i < size; i++) {
      const child = i >= 2;
      out.push({
        externalId: `G${g + 1}-${i + 1}`,
        group: `Group ${String(g + 1).padStart(4, '0')}`,
        name: `Person ${g + 1}-${i + 1}`,
        age: child ? 2 + ((g + i) % 15) : 25 + ((g * 7 + i) % 50),
        diet: DIETS[out.length % DIETS.length],
        kids: child && (g + i) % 2 === 0,
      });
    }
  });
  return {groups, people: out};
}

export const LOAD_TARGETS = ['externalId', 'group', 'name', 'age', 'field:diet', 'field:kids'];

/** The tier as a tool's CSV export, for the import. */
export function loadCsv(tier: LoadTier): string {
  return [
    'Registration ID,Group,Full name,Age,Diet,Kids activity',
    ...tier.people.map((p) =>
      [p.externalId, p.group, p.name, p.age, p.diet, p.kids ? 'yes' : 'no'].join(',')),
  ].join('\n');
}
