#pragma once

namespace ap {

/// ISO 7185 §6.4.2.2 — the integer type is the range -maxint..maxint. Note
/// this is narrower than the i32 the compiler represents it with: INT_MIN fits
/// the machine word but is not a value of the Pascal type, and arithmetic that
/// would produce it is an error.
inline constexpr int kMaxInt = 2147483647;

enum class TypeKind { Void, Integer, Real, Boolean, Char, String };

struct Type {
  TypeKind kind;

  explicit constexpr Type(TypeKind k) : kind(k) {}

  bool isInteger() const { return kind == TypeKind::Integer; }
  bool isReal() const { return kind == TypeKind::Real; }
  bool isNumeric() const { return isInteger() || isReal(); }
  bool isBoolean() const { return kind == TypeKind::Boolean; }
  bool isChar() const { return kind == TypeKind::Char; }
  bool isString() const { return kind == TypeKind::String; }

  const char *name() const {
    switch (kind) {
    case TypeKind::Integer: return "integer";
    case TypeKind::Real:    return "real";
    case TypeKind::Boolean: return "boolean";
    case TypeKind::Char:    return "char";
    case TypeKind::String:  return "string";
    case TypeKind::Void:    return "void";
    }
    return "?";
  }
};

namespace ty {
inline Type *get(TypeKind k) {
  static Type v{TypeKind::Void};
  static Type i{TypeKind::Integer};
  static Type r{TypeKind::Real};
  static Type b{TypeKind::Boolean};
  static Type c{TypeKind::Char};
  static Type s{TypeKind::String};
  switch (k) {
  case TypeKind::Integer: return &i;
  case TypeKind::Real:    return &r;
  case TypeKind::Boolean: return &b;
  case TypeKind::Char:    return &c;
  case TypeKind::String:  return &s;
  case TypeKind::Void:    break;
  }
  return &v;
}
inline Type *Int()  { return get(TypeKind::Integer); }
inline Type *Real() { return get(TypeKind::Real); }
inline Type *Bool() { return get(TypeKind::Boolean); }
inline Type *Char() { return get(TypeKind::Char); }
inline Type *Str()  { return get(TypeKind::String); }
inline Type *Void() { return get(TypeKind::Void); }
} // namespace ty

} // namespace ap
