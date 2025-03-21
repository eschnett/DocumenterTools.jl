# Deprecated module
export Travis
module Travis
    import ..DocumenterTools
    export genkeys
    function genkeys(args...; kwargs...)
        Base.depwarn("Travis.genkeys is deprecated, use DocumenterTools.genkeys instead", :genkeys)
        return DocumenterTools.genkeys(args...; kwargs...)
    end
end # module

using Base64
import LibGit2: GITHUB_REGEX
using OpenSSH_jll: ssh_keygen

"""
    DocumenterTools.genkeys(; user="\$USER", repo="\$REPO")

Generates the SSH keys necessary for the automatic deployment of documentation with
Documenter from a builder to GitHub Pages.

By default the links in the instructions need to be modified to correspond to actual URLs.
The optional `user` and `repo` keyword arguments can be specified so that the URLs in the
printed instructions could be copied directly. They should be the name of the GitHub user or
organization where the repository is hosted and the full name of the repository,
respectively.

# Examples

```jldoctest; filter = [r"ssh-rsa [A-Za-z0-9+/=.]+", r"LS0t[A-Za-z0-9+/=.]+"]
julia> using DocumenterTools

julia> DocumenterTools.genkeys()
┌ Info: Add the key below as a new 'Deploy key' on GitHub (https://github.com/\$USER/\$REPO/settings/keys) with read and write access.
└ The 'Title' field can be left empty as GitHub can infer it from the key comment.

ssh-rsa AAAAB3NzaC2yc2EAAAaDAQABAAABAQDrNsUZYBWJtXYUk21wxZbX3KxcH8EqzR3ZdTna0Wgk...jNmUiGEMKrr0aqQMZEL2BG7 Documenter

[ Info: Add a secure environment variable named 'DOCUMENTER_KEY' (to https://github.com/\$USER/\$REPO/settings/secrets if you deploy using GitHub Actions) with value:

LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBNnpiRkdXQVZpYlIy...QkVBRWFjY3BxaW9uNjFLaVdOcDU5T2YrUkdmCi0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==


julia> DocumenterTools.genkeys(user="JuliaDocs", repo="DocumenterTools.jl")
┌ Info: Add the key below as a new 'Deploy key' on GitHub (https://github.com/JuliaDocs/DocumenterTools.jl/settings/keys) with read and write access.
└ The 'Title' field can be left empty as GitHub can infer it from the key comment.

ssh-rsa AAAAB3NzaC2yc2EAAAaDAQABAAABAQDrNsUZYBWJtXYUk21wxZbX3KxcH8EqzR3ZdTna0Wgk...jNmUiGEMKrr0aqQMZEL2BG7 Documenter

[ Info: Add a secure environment variable named 'DOCUMENTER_KEY' (to https://github.com/JuliaDocs/DocumenterTools.jl/settings/secrets if you deploy using GitHub Actions) with value:

LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBNnpiRkdXQVZpYlIy...QkVBRWFjY3BxaW9uNjFLaVdOcDU5T2YrUkdmCi0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==
```
"""
function genkeys(; user="\$USER", repo="\$REPO")
    sshkeygen = ssh_keygen()

    filename  = "documenter-private-key"
    isfile(filename) && error("temporary file '$(filename)' already exists in working directory")
    isfile("$(filename).pub") && error("temporary file '$(filename).pub' already exists in working directory")

    # Generate the ssh key pair.
    mktempdir() do path
        cd(path) do
            cmd = `$(sshkeygen) -N "" -C Documenter -m PEM -f $filename`
            out, err = IOBuffer(), IOBuffer()
            try
                run(pipeline(cmd, stdout=out, stderr=err))

                # Prompt user to add public key to github then remove the public key.
                let url = "https://github.com/$user/$repo/settings/keys"
                    @info """
                    Add the key below as a new 'Deploy key' on GitHub ($url) with read and write access.
                    The 'Title' field can be left empty as GitHub can infer it from the key comment.
                    """
                    println("\n", read("$filename.pub", String))
                end

                # Base64 encode the private key and prompt user to add it to travis. The key is
                # *not* encoded for the sake of security, but instead to make it easier to
                # copy/paste it over to travis without having to worry about whitespace.
                let github_url = "https://github.com/$user/$repo/settings/secrets"
                    @info("Add a secure environment variable named 'DOCUMENTER_KEY' " *
                        "(to $(github_url) if you deploy using GitHub Actions) with value:")
                    println("\n", base64encode(read(filename, String)), "\n")
                end
            catch e
                @error """
                Failed to generate a SSH key pair.
                > stdout from ssh-keygen:
                $(String(take!(out)))
                > stderr from ssh-keygen:
                $(String(take!(err)))
                """ isfile(filename) isfile("$(filename).pub") exception = (e, catch_backtrace())
                rethrow(e)
            finally
                # mktempdir() should clean up the the files, but just in case..
                rm(filename, force=true)
                rm("$(filename).pub", force=true)
            end
        end
    end
end

"""
    genkeys(package::Module; remote="origin")

Like the other method, this generates the SSH keys necessary for the automatic deployment of
documentation with Documenter from a builder to GitHub Pages, but attempts to guess the package
URLs from the Git remote.

`package` needs to be the top level module of the package. The `remote` keyword argument can
be used to specify which Git remote is used for guessing the repository's GitHub URL.

This method requires the following command lines programs to be installed:

- `which` (Unix) or `where` (Windows)
- `git`

!!! note
    The package must be in development mode. Make sure you run
    `pkg> develop pkg` from the Pkg REPL, or `Pkg.develop(\"pkg\")`
    before generating the SSH keys.

# Examples

```julia-repl
julia> using DocumenterTools

julia> DocumenterTools.genkeys(DocumenterTools)
[Info: add the public key below to https://github.com/JuliaDocs/DocumenterTools.jl/settings/keys with read/write access:

ssh-rsa AAAAB3NzaC2yc2EAAAaDAQABAAABAQDrNsUZYBWJtXYUk21wxZbX3KxcH8EqzR3ZdTna0Wgk...jNmUiGEMKrr0aqQMZEL2BG7 username@hostname

[ Info: add a secure environment variable named 'DOCUMENTER_KEY' to https://travis-ci.com/JuliaDocs/DocumenterTools.jl/settings (if you deploy using Travis CI) or https://github.com/JuliaDocs/DocumenterTools.jl/settings/secrets (if you deploy using GitHub Actions) with value:

LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBNnpiRkdXQVZpYlIy...QkVBRWFjY3BxaW9uNjFLaVdOcDU5T2YrUkdmCi0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==
```
"""
function genkeys(package::Module; remote="origin")
    # Error checking. Do the required programs exist?
    if Sys.iswindows()
        success(`where where`)      || error("'where' not found.")
        success(`where git`)        || error("'git' not found.")
    else
        success(`which which`)      || error("'which' not found.")
        success(`which git`)        || error("'git' not found.")
    end

    path = package_devpath(package)

    # Are we in a git repo?
    user, repo = cd(path) do
        success(`git status`) || error("Failed to run `git status` in $(path). 'DocumenterTools.genkeys' only works with Git repositories.")

        let r = readchomp(`git config --get remote.$remote.url`)
            m = match(GITHUB_REGEX, r)
            m === nothing && error("no remote repo named '$remote' found.")
            m[2], m[3]
        end
    end

    # Generate the ssh key pair.
    genkeys(; user=user, repo=repo)
end
