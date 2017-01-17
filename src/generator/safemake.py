from gyp.generator import make

def FixedWriteAutoRegenerationRule(params, root_makefile, makefile_name,
                                   build_files):
  """Override the default makefile generator's WriteAutoRegenerationRule function to
  correctly handle filenames with whitespace."""

  options = params['options']
  build_files_args = [gyp.common.RelativePath(filename, options.toplevel_dir)
                      for filename in params['build_files_arg']]

  gyp_binary = gyp.common.FixIfRelativePath(params['gyp_binary'],
                                            options.toplevel_dir)
  if not gyp_binary.startswith(os.sep):
    gyp_binary = os.path.join('.', gyp_binary)

  root_makefile.write(
      "quiet_cmd_regen_makefile = ACTION Regenerating $@\n"
      "cmd_regen_makefile = cd $(srcdir); %(cmd)s\n"
      "%(makefile_name)s: %(deps)s\n"
      "\t$(call do_cmd,regen_makefile)\n\n" % {
          'makefile_name': makefile_name,
          'deps': ' '.join(QuoteSpaces(Sourceify(bf)) for bf in build_files),
          'cmd': gyp.common.EncodePOSIXShellList(
                     [gyp_binary, '--format', __file__] +
                     gyp.RegenerateFlags(options) +
                     build_files_args)})

make.WriteAutoRegenerationRule = FixedWriteAutoRegenerationRule

for exported_name in dir(make):
    globals()[exported_name] = getattr(make, exported_name)
