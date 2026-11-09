/**
 * Req 44: a small CSV reader for roster exports, following RFC 4180.
 */
import {parseCsv} from '../../src/imports/csv';

test('splits rows and cells', () => {
  expect(parseCsv('a,b\n1,2\n')).toEqual([['a', 'b'], ['1', '2']]);
});

test('handles quotes, commas and line breaks inside them, and doubled quotes', () => {
  expect(parseCsv('name,note\n"Patel, Ravi","said ""hi""\nthen left"\n')).toEqual([
    ['name', 'note'],
    ['Patel, Ravi', 'said "hi"\nthen left'],
  ]);
});

test('accepts Windows line endings, a byte-order mark, and no final newline', () => {
  expect(parseCsv('﻿a,b\r\n1,2')).toEqual([['a', 'b'], ['1', '2']]);
});

test('drops blank lines, and keeps empty cells', () => {
  expect(parseCsv('a,b\n\n1,\n,2\n\n')).toEqual([['a', 'b'], ['1', ''], ['', '2']]);
});

test('an unclosed quote is refused', () => {
  expect(() => parseCsv('a\n"open')).toThrow();
});
