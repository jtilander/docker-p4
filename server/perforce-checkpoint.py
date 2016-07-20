#!/usr/bin/python
import sys
import os
import glob


def find_current_max(root, prefix, suffix):
    """
    Instead of calling p4 counter journal (which requires some login permissions)
    we simply traverse the filesystem and check the sequence numbers.
    """
    sequence = 0
    for entry in glob.glob(os.path.join(root, '%s*%s' % (prefix, suffix))):
        name = os.path.basename(entry)
        sequence = max(sequence, int(name[len(prefix):-len(suffix)]))
    return sequence


def rotate(root, prefix, suffix, max_history):
    """
    Caps the number of checkpoints and journals that we keep in the root
    so that we don't overflow the disk.
    This should be coupled with real backups of the entire directory as well.
    """
    currentMax = find_current_max(root, prefix, suffix)
    # print "Most recent: %s%d%s" % (prefix, currentMax, suffix)

    for i in reversed(xrange(0, currentMax - max_history)):
        candidate = os.path.join(root, '%s%d%s' % (prefix, i, suffix))
        # print "Considering %s" % candidate
        if not os.path.isfile(candidate):
            break

        print "Now deleting %s" % candidate
        os.unlink(candidate)


def take_checkpoint(root):
    """
    Calls the perforce server and takes a snapshot
    """
    cmd = 'p4d -r %s -z -jc' % root
    ret = os.system(cmd)
    if ret == 0:
        return True
    return False


def main(args):
    root = os.environ.get('P4ROOT', '/data/p4depot')
    max_history = int(os.environ.get('MAX_HISTORY', '20'))

    if not take_checkpoint(root):
        return 1

    rotate(root, 'checkpoint.', '.gz', max_history)
    rotate(root, 'checkpoint.', '.md5', max_history)
    rotate(root, 'journal.', '.gz', max_history)

    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
