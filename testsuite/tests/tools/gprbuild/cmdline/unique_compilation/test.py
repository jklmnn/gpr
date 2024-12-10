import os
import json
from e3.fs import rm
from testsuite_support.builder_and_runner import BuilderAndRunner

bnr = BuilderAndRunner()

def run(cmd, cwd="", quiet=False):
    if cwd != "":
        old_cwd = os.getcwd()
        os.chdir(cwd)
    if not quiet:
        if isinstance (cmd, str):
            print("$ " + cmd);
        else:
            print("$ " + " ".join(cmd));
    if cmd[0].startswith("gpr2"):
        bnr.call(cmd)
    else:
        print(bnr.simple_run([cmd], catch_error=True).out)
    if cwd != "":
        os.chdir(old_cwd)

def test(prj, switches, cleanup=True):
    run(["gpr2build", "-P", prj, "-q", "-p", "-k", "--json-summary"] + switches)
    if os.path.exists("jobs.json"):
        with open("jobs.json") as fp:
            cnt = json.load(fp)
        rm("jobs.json")
        uids = dict((job["uid"], job) for job in cnt)

        for uid in sorted(uids):
            if uids[uid]["status"] != "SKIPPED":
                print(uid)

    if cleanup:
        run(["gpr2clean", "-P", prj, "-q", "-r"], quiet=True)


test("demo.gpr", ["-u"])
test("demo.gpr", ["-U"])
test("abst.gpr", ["-u", "pkg2.ads"])
test("abst.gpr", ["-U", "pkg2.ads"])
test("abst.gpr", ["-U", "non_existing.ads"])
test("abst.gpr", ["-c", "pkg2.ads"])
test("demo.gpr", ["main.adb", "-c"], False)
test("demo.gpr", ["main.adb", "-b"], False)
test("demo.gpr", ["main.adb", "-l"], False)
run(["./main"])
