_DEFAULT_LIB = "go_default_library"

_VENDOR_PREFIX = "/vendor/"

def _go_prefix(ctx):
  """slash terminated go-prefix"""
  prefix = ctx.rule.attr.go_prefix.go_prefix
  if prefix != "" and not prefix.endswith("/"):
    prefix = prefix + "/"
  return prefix

def _go_importpath(ctx):
  """Returns the expected importpath of the go_library being built.

  Args:
    ctx: The skylark Context

  Returns:
    Go importpath of the library
  """
  path = _go_prefix(ctx)[:-1]
  if ctx.label.package:
    path += "/" + ctx.label.package
  if ctx.label.name != _DEFAULT_LIB:
    path += "/" + ctx.label.name
  if path.rfind(_VENDOR_PREFIX) != -1:
    path = path[len(_VENDOR_PREFIX) + path.rfind(_VENDOR_PREFIX):]
  if path[0] == "/":
    path = path[1:]
  return path

def _gopath_aspect_impl(target, ctx):
  importpath = _go_importpath(ctx)
  gopath = []
  if hasattr(target, 'go_sources'):
    gopath = gopath + [struct(importpath=importpath, file=s) for s in target.go_sources]
  for dep in ctx.rule.attr.deps:
    gopath += dep.gopath
  if ctx.rule.attr.library:
    gopath += ctx.rule.attr.library.gopath

  return struct(gopath = gopath)


gopath_aspect = aspect(
  implementation = _gopath_aspect_impl,
  attr_aspects = ["deps", "library"],
)

def _build_gopath_impl(ctx):
  ctx.file_action(
    ctx.outputs.executable,
    "#!/bin/bash\ntree",
    executable = True
  )
  links = dict()
  for dep in ctx.attr.deps:
    for entry in dep.gopath:
      linked = "src/" + entry.importpath + "/" + entry.file.basename
      links[linked] = entry.file
  return struct(
    runfiles = ctx.runfiles(
      symlinks=links,
      collect_data=False,
      collect_default=False),
  )

build_gopath = rule(
  implementation = _build_gopath_impl,
  attrs = {
    "deps": attr.label_list(aspects = [gopath_aspect]),
  },
  executable = True,
)
