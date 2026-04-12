// taken from:
// - https://github.com/nyxx-discord/nyxx/blob/main/lib/src/utils/iterable_extension.dart
//
//   Copyright 2021 Szymon Uglis, Harry Bairstow and contributors
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

/// An internal extension adding utility methods to [Iterable].
extension IterableExtension<T> on Iterable<T> {
  /// Same as [firstWhere], but returns `null` is no element is found.
  ///
  /// Also allows for [orElse] to return `null`.
  T? firstWhereSafe(bool Function(T element) test, {T? Function()? orElse}) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }

    if (orElse != null) {
      return orElse();
    }

    return null;
  }
}

/// An internal extension adding utility methods to [Stream].
extension StreamExtension<T> on Stream<T> {
  /// Equivalent to [Iterable.whereType].
  Stream<U> whereType<U>() => where((event) => event is U).cast<U>();
}
