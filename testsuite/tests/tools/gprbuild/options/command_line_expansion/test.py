import glob
import json
import os.path
import shutil
from e3.env import Env
from e3.os.process import Run


from testsuite_support.builder_and_runner import BuilderAndRunner, GPR2BUILD

bnr = BuilderAndRunner()

compiler_suffix=""
if Env().host.platform.endswith('windows') or Env().host.platform.endswith('windows64'):
	compiler_suffix=".exe"

print("Step 1 - Check -cargs")
out = bnr.check_output([GPR2BUILD, "-P", os.path.join("tree", "main.gpr"), "-p", "-v", "-cargs", "-O2", "-cargs:Ada", "-O1", "-cargs:C", "-O0"])
for line in out.out.split("\n"):
	if f"gcc{compiler_suffix} -c" in line:
		print(line)

print("Step 2 - Check -bargs")
out = bnr.check_output([GPR2BUILD, "-P", os.path.join("tree_2", "main.gpr"), "-p", "-v", "-bargs", "-O=3.bind", "-bargs:Ada", "-O=5.bind", "-bargs", "-O=4.bind", "-bargs:Ada", "-O=6.bind"])
for line in out.out.split("\n"):
	if f"gnatbind{compiler_suffix}" in line:
		print(line)

print("Step 3 - Check -largs")
out = bnr.check_output([GPR2BUILD, "-P", os.path.join("tree_3", "main.gpr"), "-p", "-v", "-largs", "-Wl,2"])
for line in out.out.split("\n"):
	if f"gcc{compiler_suffix} -o main" in line:
		print(line)

print("Step 4 - Check -margs / -gargs")
shutil.rmtree("tree/obj")

print("   - without '-margs -p' / '-gargs -p'")
bnr.call([GPR2BUILD, "-P", os.path.join("tree", "main.gpr")])

print("   - with '-margs -p'")
out = bnr.check_output([GPR2BUILD, "-P", os.path.join("tree", "main.gpr"), "-margs", "-p"])
for line in out.out.split("\n"):
	if f"created" in line:
		print(line)

shutil.rmtree("tree/obj")

print("   - with '-gargs -p'")
out = bnr.check_output([GPR2BUILD, "-P", os.path.join("tree", "main.gpr"), "-margs", "-p"])
for line in out.out.split("\n"):
	if f"created" in line:
		print(line)
