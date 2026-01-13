# C++ Header (.h) vs Implementation (.cpp) Files

## Quick Overview

- **`.h` files** = Header files (declarations)
- **`.cpp` files** = Implementation files (definitions)

They work together as a pair.

---

## Detailed Explanation

### `.h` Files (Header Files)

**Purpose**: Declare what exists, not how it works

**Contains**:
- Function declarations (signatures only)
- Struct/class definitions
- Constants and macros
- Type definitions

**Example** (`ffmpeg_common.h`):
```cpp
struct FFmpegContext {
    AVFormatContext* ifmt_ctx;
    AVCodecContext* dec_ctx;
    // ... more fields
};

// Declaration: "this function exists"
int ffmpeg_open_input(FFmpegContext* ctx, const char* input_file);
```

**Think of it as**: A contract or interface that says "here's what I provide"

---

### `.cpp` Files (Implementation Files)

**Purpose**: Implement the actual logic

**Contains**:
- Function implementations (the actual code)
- Variable definitions
- Logic and algorithms

**Example** (`ffmpeg_common.cpp`):
```cpp
// Implementation: "here's how it actually works"
int ffmpeg_open_input(FFmpegContext* ctx, const char* input_file) {
    if (!ctx || !input_file) return -1;
    
    if (avformat_open_input(&ctx->ifmt_ctx, input_file, nullptr, nullptr) < 0) {
        LOGE("Cannot open input file: %s", input_file);
        return -1;
    }
    
    // ... more code
    return 0;
}
```

---

## Why Separate Files?

### 1. **Compilation Speed**
- Other files only need to include `.h` (small)
- Don't recompile `.cpp` unless it changes
- Faster builds

### 2. **Modularity**
- `.h` = public interface (what users see)
- `.cpp` = private implementation (how it works)
- Users don't need to know implementation details

### 3. **Code Organization**
- Clear separation of concerns
- Easy to find declarations vs implementations
- Professional C++ practice

---

## How They Work Together

```
myffmpeg.cpp (JNI entry point)
    ↓
    #include "ffmpeg_common.h"  ← Reads declarations
    ↓
    Uses ffmpeg_open_input()
    ↓
    Linker finds implementation in ffmpeg_common.cpp
    ↓
    Calls the actual function
```

### Step-by-Step Example

**1. Header declares it exists** (`ffmpeg_common.h`):
```cpp
int ffmpeg_open_input(FFmpegContext* ctx, const char* input_file);
```

**2. Implementation provides the code** (`ffmpeg_common.cpp`):
```cpp
int ffmpeg_open_input(FFmpegContext* ctx, const char* input_file) {
    // actual implementation
}
```

**3. Another file uses it** (`myffmpeg.cpp`):
```cpp
#include "ffmpeg_common.h"  // Tells compiler: "this function exists"

// Later in code:
if ((ret = ffmpeg_open_input(&ctx.ffmpeg_ctx, input_file)) < 0) {
    // Linker will find the implementation in ffmpeg_common.cpp
}
```

---

## Your Project Structure

```
ffmpeg_common.h          ← Declares: init, open_input, setup_decoder, etc.
ffmpeg_common.cpp        ← Implements all those functions

ffmpeg_text_overlay.h    ← Declares: text_overlay_init, setup_filter, etc.
ffmpeg_text_overlay.cpp  ← Implements all those functions

myffmpeg.cpp             ← JNI entry point (uses both headers)
```

---

## Compilation Process

```
1. Compiler reads myffmpeg.cpp
   ↓
2. Sees #include "ffmpeg_common.h"
   ↓
3. Reads declarations from .h file
   ↓
4. Compiler says: "OK, these functions exist somewhere"
   ↓
5. Compiler compiles myffmpeg.cpp → myffmpeg.o
   ↓
6. Compiler compiles ffmpeg_common.cpp → ffmpeg_common.o
   ↓
7. Linker combines all .o files
   ↓
8. Linker finds: "ffmpeg_open_input is declared in .h and implemented in ffmpeg_common.o"
   ↓
9. Links them together → libmyffmpeg.so
```

---

## Key Differences

| Aspect | `.h` (Header) | `.cpp` (Implementation) |
|--------|---------------|------------------------|
| **Contains** | Declarations | Implementations |
| **Included by** | Other files | Compiled separately |
| **Size** | Small | Can be large |
| **Recompile when** | Rarely | Often |
| **Users see** | Yes (interface) | No (hidden) |

---

## Real-World Analogy

Think of a restaurant:

- **`.h` file** = Menu (what's available)
  - "We have hamburgers, pizza, salads"
  - Just tells you what exists

- **`.cpp` file** = Kitchen (how it's made)
  - Recipe for hamburgers
  - Recipe for pizza
  - Hidden from customers

- **Customer** = Your code using the functions
  - Reads the menu (includes .h)
  - Orders food (calls function)
  - Doesn't care how it's made (doesn't see .cpp)

---

## Best Practices

### 1. **Include Guards**
Always use include guards in `.h` files to prevent duplicate includes:
```cpp
#ifndef FFMPEG_COMMON_H
#define FFMPEG_COMMON_H

// ... declarations ...

#endif // FFMPEG_COMMON_H
```

### 2. **Forward Declarations**
Use forward declarations in headers to reduce dependencies:
```cpp
// Instead of including the full header:
struct AVFormatContext;  // Forward declaration
int process_format(AVFormatContext* ctx);
```

### 3. **Keep Headers Clean**
- Only include what's necessary
- Put implementation details in `.cpp`
- Use `extern "C"` for C libraries

### 4. **One Class/Module Per Pair**
- `ffmpeg_common.h` + `ffmpeg_common.cpp` = Common utilities
- `ffmpeg_text_overlay.h` + `ffmpeg_text_overlay.cpp` = Text overlay feature
- `ffmpeg_blur.h` + `ffmpeg_blur.cpp` = Blur feature (future)

---

## Summary

- **`.h` files** = "What exists" (declarations)
- **`.cpp` files** = "How it works" (implementations)
- **Same name** = They're a pair (one declares, one implements)
- **Both needed** = Header for interface, implementation for logic
- **Professional practice** = Standard C++ way of organizing code

---

## Related Files in This Project

- [REFACTORING_NOTES.md](../REFACTORING_NOTES.md) - Architecture overview
- [android/app/src/main/cpp/](../../android/app/src/main/cpp/) - All C++ source files
