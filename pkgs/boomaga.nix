{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  cups,
  poppler,
  zlib,
  qtbase,
  qttools,
  wrapQtAppsHook,
}:
stdenv.mkDerivation rec {
  pname = "boomaga";
  version = "3.7.0";

  src = fetchFromGitHub {
    owner = "Boomaga";
    repo = "boomaga";
    rev = "v${version}";
    hash = "sha256-oooExzsuxgA11ypCPdwLk98FxfLfWwcViMhwQIlZ98E=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qttools
    wrapQtAppsHook
  ];

  buildInputs = [
    cups.dev
    poppler
    zlib
    qtbase
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    "-DCUPS_PPD_DIR=${placeholder "out"}/share/cups/model/boomaga"
    "-DCUPS_BACKEND_DIR=${placeholder "out"}/lib/cups/backend"
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ];

  # The CUPS backend is written to run as root: it chowns the spool file
  # and setuids to the job owner before execing the GUI. cupsd on NixOS
  # spawns backends as cups:lp, so when not root the backend publishes
  # the spool file for the user session helper (services.boomaga watcher)
  # instead: group-readable, atomically renamed into place, no setuid.
  postPatch = ''
            substituteInPlace src/backend/cups_backend/main.cpp \
              --replace-fail '#include <string>' '#include <string>
        #include <cstdio>' \
              --replace-fail '    ofstream dest(destFile, ios::binary | ios::trunc);' '    string tmpFile = destFile + ".tmp";
            ofstream dest(tmpFile, ios::binary | ios::trunc);' \
              --replace-fail '        unlink(destFile.c_str());' '        unlink(tmpFile.c_str());' \
              --replace-fail '    if (chown(destFile.c_str(), args.pwd->pw_uid, -1) != 0)' '    { bool csOk = ((chown(tmpFile.c_str(), args.pwd->pw_uid, -1) == 0) || (errno == EPERM)); if (!csOk) { Log::error("Cannot change owner of %s: %s", tmpFile.c_str(), std::strerror(errno)); unlink(tmpFile.c_str()); return false; } chmod(tmpFile.c_str(), 0640); if (rename(tmpFile.c_str(), destFile.c_str()) != 0) { Log::error("Cannot publish job file %s: %s", destFile.c_str(), std::strerror(errno)); unlink(tmpFile.c_str()); return false; } } if (false)' \
              --replace-fail '    if (chown(dir.c_str(), pwd->pw_uid, -1) != 0)' '    if ((chown(dir.c_str(), pwd->pw_uid, -1) != 0) && (errno != EPERM))' \
              --replace-fail '    args.file    = (argc > 6) ? argv[6] : "";' '    args.file    = (argc > 6) ? argv[6] : "";

            if (args.jobID.find("/", 0) != string::npos)
            {
                Log::error("Invalid job ID %s.", args.jobID.c_str());
                return CUPS_BACKEND_FAILED;
            }' \
              --replace-fail '    if (setgid(args.pwd->pw_gid) != 0)' '    if (getuid() != 0)
            {
                // Unprivileged (cupsd spawns backends as cups:lp): the spool
                // file is published above; the user session helper picks it up.
                Log::debug("Not running as root, leaving job file for the user session helper");
                return CUPS_BACKEND_OK;
            }

            if (setgid(args.pwd->pw_gid) != 0)'
        # The GUI merges synchronously in the UI thread while pumping events,
        # so closing the window mid-merge runs Project::free() re-entrantly on
        # live merge data (use-after-free -> SEGV, seen in a coredump with the
        # fault in Project::free under QWidgetWindow::closeEvent). Defer the
        # close instead: the window closes once the in-flight merge finishes.
        substituteInPlace src/boomaga/kernel/project.h \
          --replace-fail '    const JobList *jobs() const { return &mJobs; }' '    const JobList *jobs() const { return &mJobs; }
        bool isMerging() const { return mMergeDepth > 0; }
        void requestClose() { mCloseRequested = true; }' \
          --replace-fail '    void longTaskStarted(const ProjectLongTask *task);' '    void longTaskStarted(const ProjectLongTask *task);
        void closeRequested();' \
          --replace-fail '    TmpPdfFile *mTmpFile;
        TmpPdfFile *mLastTmpFile;' '    TmpPdfFile *mTmpFile;
        TmpPdfFile *mLastTmpFile;
        int mMergeDepth = 0;
        bool mCloseRequested = false;'
        substituteInPlace src/boomaga/kernel/project.cpp \
          --replace-fail '        stopMerging();
            update();

            mLastTmpFile = createTmpPdfFile();
            mLastTmpFile->merge(mJobs);' '        stopMerging();
            update();

            mLastTmpFile = createTmpPdfFile();
            mMergeDepth++;
            mLastTmpFile->merge(mJobs);
            mMergeDepth--;
            if (mCloseRequested)
            {
                mCloseRequested = false;
                emit closeRequested();
            }' \
          --replace-fail '    catch (BoomagaError &err)
        {
            qWarning() << Q_FUNC_INFO << err.what();
            error(err.what());
        }' '    catch (BoomagaError &err)
        {
            mMergeDepth = 0;
            qWarning() << Q_FUNC_INFO << err.what();
            error(err.what());
            if (mCloseRequested)
            {
                mCloseRequested = false;
                emit closeRequested();
            }
        }'
        substituteInPlace src/boomaga/gui/mainwindow.cpp \
          --replace-fail 'void MainWindow::closeEvent(QCloseEvent*)
    {
        project->free();
    }' 'void MainWindow::closeEvent(QCloseEvent *event)
    {
        if (project->isMerging())
        {
            project->requestClose();
            statusBar()->showMessage(tr("Finishing merge before closing..."), 3000);
            event->ignore();
            return;
        }
        project->free();
    }' \
          --replace-fail '    connect(project, SIGNAL(changed()),
                this, SLOT(updateWidgets()));' '    connect(project, SIGNAL(changed()),
                this, SLOT(updateWidgets()));

        connect(project, SIGNAL(closeRequested()),
                this, SLOT(close()));'
  '';

  meta = with lib; {
    description = "Virtual printer for viewing and editing before printing";
    homepage = "https://github.com/Boomaga/boomaga";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
}
