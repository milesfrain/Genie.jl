"""
Generates various Genie files.
"""
module Generator

using Revise, Genie, Genie.Loggers, Genie.FileTemplates, Genie.Inflector, Genie.Configuration


"""
    newcontroller(cmd_args::Dict{String,Any}) :: Nothing

Generates a new Genie controller file and persists it to the resources folder.
"""
function newcontroller(cmd_args::Dict{String,Any}; path::String = ".", pluralize::Bool = true) :: Nothing
  resource_name = cmd_args["controller:new"]
  Genie.Inflector.is_singular(resource_name) && pluralize && (resource_name = Inflector.to_plural(resource_name) |> Base.get)
  resource_name = uppercasefirst(resource_name)

  resource_path = setup_resource_path(resource_name, path = path)
  cfn = controller_file_name(resource_name)
  write_resource_file(resource_path, cfn, resource_name, :controller, pluralize = pluralize) &&
    log("New controller created at $(joinpath(resource_path, cfn))")

  nothing
end


"""
    newresource(cmd_args::Dict{String,Any}, config::Settings) :: Nothing
    newresource(resource_name::Union{String,Symbol}) :: Nothing

Generates all the files associated with a new resource and persists them to the resources folder.
"""
function newresource(cmd_args::Dict{String,Any}; path::String = ".", pluralize::Bool = true) :: Nothing
  resource_name = uppercasefirst(cmd_args["resource:new"])

  if Genie.Inflector.is_singular(resource_name) && pluralize
    resource_name = Genie.Inflector.to_plural(resource_name) |> Base.get
  end

  resource_path = setup_resource_path(resource_name, path = path)
  for (resource_file, resource_type) in [(controller_file_name(resource_name), :controller)]
    write_resource_file(resource_path, resource_file, resource_name, resource_type, pluralize = pluralize) &&
      log("New $resource_file created at $(joinpath(resource_path, resource_file))")
  end

  views_path = joinpath(resource_path, "views")
  ! isdir(views_path) && mkpath(views_path)

  ! isdir(Genie.TEST_PATH_UNIT) && mkpath(Genie.TEST_PATH_UNIT)
  test_file = resource_name * Genie.TEST_FILE_IDENTIFIER |> lowercase
  write_resource_file(Genie.TEST_PATH_UNIT, test_file, resource_name, :test, pluralize = pluralize) &&
    log("New $test_file created at $(joinpath(Genie.TEST_PATH_UNIT, test_file))")

  nothing
end
function newresource(resource_name::Union{String,Symbol}; path::String = ".", pluralize::Bool = true) :: Nothing
  newresource(Dict{String,Any}("resource:new" => string(resource_name)), path = path, pluralize = pluralize)
end


"""
    setup_resource_path(resource_name::String) :: String

Computes and creates the directories structure needed to persist a new resource.
"""
function setup_resource_path(resource_name::String; path::String = ".") :: String
  isdir(Genie.APP_PATH) || Genie.REPL.copy_mvc_support(path)

  resource_path = joinpath(path, Genie.RESOURCES_PATH, lowercase(resource_name))

  if ! isdir(resource_path)
    mkpath(resource_path)
    push!(LOAD_PATH, resource_path)
  end

  resource_path
end


"""
    write_resource_file(resource_path::String, file_name::String, resource_name::String) :: Bool

Generates all resouce files and persists them to disk.
"""
function write_resource_file(resource_path::String, file_name::String, resource_name::String, resource_type::Symbol; pluralize::Bool = true) :: Bool
  resource_name = (pluralize ? Base.get(Inflector.to_plural(resource_name)) : resource_name) |> Inflector.from_underscores

  try
    if resource_type == :controller
      resource_does_not_exist(resource_path, file_name) || return true
      open(joinpath(resource_path, file_name), "w") do f
        write(f, Genie.FileTemplates.newcontroller(resource_name))
      end

    elseif resource_type == :test
      resource_does_not_exist(resource_path, file_name) || return true
      open(joinpath(resource_path, file_name), "w") do f
        write(f, Genie.FileTemplates.newtest(resource_name, Base.get(Inflector.to_singular(resource_name)) ))
      end

    else
      error("Not supported, $file_name")
    end
  catch ex
    log(ex, :warn)
  end

  try
    Genie.load_resources()
  catch ex
    log(ex, :warn)
  end

  true
end


function resource_does_not_exist(resource_path::String, file_name::String) :: Bool
  if isfile(joinpath(resource_path, file_name))
    log("File already exists, $(joinpath(resource_path, file_name)) - skipping", :warn)
    return false
  end

  true
end


function controller_file_name(resource_name::Union{String,Symbol})
  string(resource_name) * Genie.GENIE_CONTROLLER_FILE_POSTFIX
end


end
