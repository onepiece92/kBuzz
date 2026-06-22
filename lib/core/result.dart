import 'package:equatable/equatable.dart';

/// Typed failures + a result wrapper used at layer boundaries.
///
/// Repositories return a [Result] instead of throwing, so the presentation and
/// state layers never catch raw `dio` / `drift` / Firestore exceptions
/// (AGENTS.md §12: "No exceptions across layer boundaries"). Data-layer code
/// maps its errors into one of the [AppFailure] subtypes.

/// Base type for all recoverable failures crossing a layer boundary.
sealed class AppFailure extends Equatable {
  const AppFailure(this.message, {this.cause});

  /// Human-readable, log/UI-safe description.
  final String message;

  /// The original error, kept for logging — never surfaced raw to the UI.
  final Object? cause;

  @override
  List<Object?> get props => <Object?>[message, cause];
}

/// A failure originating from local storage (Drift).
class CacheFailure extends AppFailure {
  const CacheFailure(super.message, {super.cause});
}

/// A failure originating from the network (dio / Firestore).
class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause});
}

/// A catch-all for anything not yet categorised.
class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message, {super.cause});
}

/// The outcome of an operation that can fail without throwing.
sealed class Result<T> {
  const Result();

  /// A successful result carrying [value].
  const factory Result.ok(T value) = Ok<T>;

  /// A failed result carrying an [AppFailure].
  const factory Result.err(AppFailure failure) = Err<T>;

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// Collapse both branches into a single value.
  R when<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) {
    final Result<T> self = this;
    return switch (self) {
      Ok<T>(:final T value) => ok(value),
      Err<T>(:final AppFailure failure) => err(failure),
    };
  }
}

/// A successful [Result].
class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

/// A failed [Result].
class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;
}
