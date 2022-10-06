//
// Read the configs
// Determine list of watch directories
const dotenv = require('dotenv')
const dotex = require('dotenv-expand')
const dot = dotex.expand(dotenv.config());
const glob = require('glob');
const {spawn, execSync} = require('node:child_process');

const CLSYNC = process.env.CLSYNC || "clsync";
const HANDLER = process.env.HANDLER || "/usr/local/bin/synchandler.pl";
const SKIP_INITIAL_SYNC = (process.env.SYNCH_SKIP_INITIAL_SYNC === "true") ? true : false;

const parseWatchDirs = async (watchDirsString) => {

    console.log("parseWatchDirs received ", watchDirsString);

    const watchDirs = JSON.parse(watchDirsString);
    var dirArray = [];

    // support for wildcards
    const getPaths = (pattern) => {
        return new Promise((resolve, reject) => {
            glob(pattern, {"nonull": true}, (error, files) => {
                if (error) {
                    reject(error);
                } else {
                    resolve(files);
                }
            });
        });
    }

    const allProms = watchDirs.map(async (pathset) => {
        let path, s3add, s3del;
        [path, s3add, s3del] = pathset;
        console.log(" trying to get paths: " + path);
        console.log("         using s3add: " + s3add);
        console.log("         using s3del: " + s3del);

        const paths = await getPaths(path);
        return paths.map((p) => {
            return [p, s3add, s3del]
        });

    });
    const result = await Promise.all(allProms);

    // return a unique list of paths
    return [...new Set([].concat(...result))];
};

async function start() {
    const watchDirs = await parseWatchDirs(process.env.WATCHDIRS);

    console.log("GOT watchDirs: ", watchDirs);


    watchDirs.forEach((configset) => {
        let watchdir, s3add, s3del;
        [watchdir, s3add, s3del] = configset;
        console.log("WATCHDIR ", watchdir);
        console.log("S3ADD", s3add);
        console.log("S3DEL", s3del);

        const BASEARGS = [
            "-w5",
            "-t5",
            "--one-file-system",
            "--mode=direct",
            "--watch-dir=" + watchdir,
            "--sync-handler=" + HANDLER
        ];
        if (SKIP_INITIAL_SYNC) {
            console.log("CLSYNC: Skipping initial sync...");
            BASEARGS.push("--skip-initialsync");
        }
        const ARGS = BASEARGS.concat([
            "--",
            "%INCLUDE-LIST%",
            watchdir,
            s3add,
            s3del
        ]);

        console.log("SPAWNING: " + CLSYNC + " " + ARGS.join(' '));
        const proc = spawn(CLSYNC, ARGS);
        proc.stdout.on('data', (message) => {
            console.log("stdio message for " + watchdir + ":\n ", message.toString());
        });
        proc.stderr.on('data', (message) => {
            console.error("stderr message for " + watchdir + ":\n ", message.toString());
        });
        proc.on('close', (message) => {
            console.log(watchdir + " close message = ", message);
        });
        proc.on('exit', (message) => {
            console.log(watchdir + " exit message = ", message);
        });
        proc.on('spawn', (message) => {
            console.log("SPAWNED solr sync for " + watchdir);
        });
        proc.on('disconnect', (message) => {
            console.log(watchdir, " disconnect message = ", message);
        });
    });
}

start().then(() => {
    console.error("We are now done.  Bye!")
}).catch((reason) => {
    console.error("Couldn't launch app ", reason)
})