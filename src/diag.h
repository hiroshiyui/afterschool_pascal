#pragma once
#include <string>
#include <vector>

namespace ap {

struct Diagnostic {
  int line;
  int col;
  std::string message;
};

/// Collects errors from every stage so one bad file can report more than one
/// problem before we give up.
class Diagnostics {
public:
  explicit Diagnostics(std::string filename) : file_(std::move(filename)) {}

  void error(int line, int col, std::string message);
  bool hasErrors() const { return !diags_.empty(); }
  size_t count() const { return diags_.size(); }
  void print() const;

  const std::string &filename() const { return file_; }

private:
  std::string file_;
  std::vector<Diagnostic> diags_;
};

} // namespace ap
