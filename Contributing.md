# Contributing to GUI Tester

Please try and follows the things that are layed out below as it will make it easier to accept a pull request however not following the below does not necessarily exclude a pull request from being accepted.

## Git [Flow]

For [GUI Tester](https://github.com/DGH2112/GUITester) I use Git as the version control but I also use [Git Flow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) for the development cycles. Git Flow has been removed from Git now but I still follow the methodology manually with **master**, **develop**, **Release**, **HotFix** and **BugFix** branches. The main development is undertaken in the **develop** branch with stable releases being in the **master**. All pull requests should be made from the **develop** branch, prefereably using **Feature**, **HotFix** or **BugFix** branches. You should submit only one change per pull request at a time to make it easiler to review and accept the pull request.

Tools wise, I sometimes use Fork but have mainly reverted to using a command prmopt (Take Command).

## Creating Pull Requests

Having not done this before as I've always been the sole contributor to my repositories so I borrowed the essense of the following from the [DUnitX](https://github.com/VSoftTechnologies/DUnitX) project:

1. Create a [GitHub Account](https://github.com/join);
2. Fork the [GUI Tester](https://github.com/DGH2112/GUITester)
   Repository and setup your local repository as follows:
     * [Fork the repository](https://help.github.com/articles/fork-a-repo);
     * Clone your Fork to your local machine;
     * Configure upstream remote to the **develop**
       [GUI Tester](https://github.com/DGH2112/GUITester)
       repository [GUI Tester](https://github.com/DGH2112/GUITester);
3. For each change you want to make:
     * Create a new **Feature** or **BugFix** branch for your change;
     * Make your change in your new branch;
     * **Verify code compiles in RAD Studio 13.x and any unit tests still pass**;
     * Commit change to your local repository;
     * Push change to your remote repository;
     * Submit a [Pull Request](https://help.github.com/articles/using-pull-requests);
     * Note: local and remote branches can be deleted after pull request has been accepted.

**Note:** Getting changes from others requires [Syncing your Local repository](https://help.github.com/articles/syncing-a-fork) with the **develop** [GUI Tester](https://github.com/DGH2112/GUITester) repository. This can happen at any time.

## Dependencies

[GUI Tester](https://github.com/DGH2112/GUITester) has the following dependencies as submodules:

* PyScript SynEdit;
* DDetours;
* VCL Styles;
* Spring4D;
* FastMM4.

## Project Configuration

The [GUI Tester](https://github.com/DGH2112/GUITester) .

## Rationale



regards

David Hoyle Dec 2021
