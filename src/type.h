#pragma once
#include <string>
#include <vector>

namespace ap {

/// ISO 7185 §6.4.2.2 — the integer type is the range -maxint..maxint. Note
/// this is narrower than the i32 the compiler represents it with: INT_MIN fits
/// the machine word but is not a value of the Pascal type, and arithmetic that
/// would produce it is an error.
inline constexpr int kMaxInt = 2147483647;

enum class TypeKind { Void, Integer, Real, Boolean, Char, Array, Record };

struct Type;

/// One field of a record. `index` is the position in the LLVM struct, which is
/// also the declaration order — codegen indexes by it and never by name.
struct Field {
  std::string name;
  Type *type = nullptr;
  int index = 0;
  int line = 0, col = 0;
};

/// A Pascal type. Simple types are shared singletons; every array or record
/// *type-denoter* in the source produces one of these, and a type identifier
/// names the one its definition produced. Identity is therefore what ISO 7185
/// §6.4.5 calls "the same type", so structured types compare by pointer —
/// see ADR-0017.
struct Type {
  TypeKind kind;

  explicit Type(TypeKind k) : kind(k) {}

  // --- array ---------------------------------------------------------------
  Type *elem = nullptr;      // component type
  Type *indexType = nullptr; // integer or char; the type of a subscript
  long long lo = 0, hi = -1; // index bounds, inclusive
  bool packed = false;

  // --- record --------------------------------------------------------------
  std::vector<Field> fields;

  /// The identifier a `type` definition gave this, purely for diagnostics.
  std::string alias;

  bool isInteger() const { return kind == TypeKind::Integer; }
  bool isReal() const { return kind == TypeKind::Real; }
  bool isNumeric() const { return isInteger() || isReal(); }
  bool isBoolean() const { return kind == TypeKind::Boolean; }
  bool isChar() const { return kind == TypeKind::Char; }
  bool isArray() const { return kind == TypeKind::Array; }
  bool isRecord() const { return kind == TypeKind::Record; }

  /// Arrays and records live in memory and are copied wholesale; simple types
  /// live in registers. The distinction drives assignment, parameter passing,
  /// and whether an expression may be loaded at all.
  bool isStructured() const { return isArray() || isRecord(); }
  bool isOrdinal() const { return isInteger() || isChar() || isBoolean(); }

  long long length() const { return hi - lo + 1; }

  /// A `packed array [m..n] of char` — the type ISO 7185 §6.4.3.2 gives a
  /// string literal, and the only structured type with its own operators.
  bool isCharArray() const {
    return isArray() && packed && elem && elem->isChar();
  }

  const Field *findField(const std::string &n) const {
    for (const Field &f : fields)
      if (f.name == n)
        return &f;
    return nullptr;
  }

  /// A description for diagnostics. A named type reports its name; an
  /// anonymous one is spelled out the way the source would have written it.
  std::string name() const {
    if (!alias.empty())
      return alias;
    switch (kind) {
    case TypeKind::Integer: return "integer";
    case TypeKind::Real:    return "real";
    case TypeKind::Boolean: return "boolean";
    case TypeKind::Char:    return "char";
    case TypeKind::Void:    return "void";
    case TypeKind::Record: {
      // An anonymous record is named by its fields, which is the only thing
      // that distinguishes it from any other anonymous record.
      std::string s = "record ";
      for (size_t i = 0; i < fields.size(); ++i)
        s += (i ? ", " : "") + fields[i].name;
      return s + " end";
    }
    case TypeKind::Array:
      break;
    }
    std::string s = packed ? "packed array [" : "array [";
    if (indexType && indexType->isChar())
      s += "'" + std::string(1, static_cast<char>(lo)) + "'..'" +
           std::string(1, static_cast<char>(hi)) + "'";
    else
      s += std::to_string(lo) + ".." + std::to_string(hi);
    return s + "] of " + (elem ? elem->name() : "?");
  }
};

namespace ty {
inline Type *get(TypeKind k) {
  static Type v{TypeKind::Void};
  static Type i{TypeKind::Integer};
  static Type r{TypeKind::Real};
  static Type b{TypeKind::Boolean};
  static Type c{TypeKind::Char};
  switch (k) {
  case TypeKind::Integer: return &i;
  case TypeKind::Real:    return &r;
  case TypeKind::Boolean: return &b;
  case TypeKind::Char:    return &c;
  default:                break;
  }
  return &v;
}
inline Type *Int()  { return get(TypeKind::Integer); }
inline Type *Real() { return get(TypeKind::Real); }
inline Type *Bool() { return get(TypeKind::Boolean); }
inline Type *Char() { return get(TypeKind::Char); }
inline Type *Void() { return get(TypeKind::Void); }
} // namespace ty

} // namespace ap
