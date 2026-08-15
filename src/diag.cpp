#include "diag.h"

#include <cstdio>

namespace ap {

void Diagnostics::error(int line, int col, std::string message) {
  diags_.push_back({line, col, std::move(message)});
}

void Diagnostics::print() const {
  for (const auto &d : diags_)
    std::fprintf(stderr, "%s:%d:%d: error: %s\n", file_.c_str(), d.line, d.col,
                 d.message.c_str());
}

} // namespace ap
