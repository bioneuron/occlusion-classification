function run(task, varargin)

allowedTasks = {'classification', 'features', 'features-hop'};
assert(ismember(task, allowedTasks), ['task must be one of: ', ...
    sprintf('''%s'', ', allowedTasks{1:end - 1}), '''', ...
    allowedTasks{end}, '''']);

% dataset = load('dataset_extended.mat');
dataset = load('data/data_occlusion_klab325v2.mat');
dataset = dataset.data;

%% Args
argParser = inputParser();
argParser.KeepUnmatched = true;
argParser.addParameter('dataSelection', 1:size(dataset, 1), @isnumeric);

argParser.parse(varargin{:});
fprintf('Running %s in %s with args:\n', task, pwd);
disp(argParser.Results);
dataSelection = argParser.Results.dataSelection;

%% Feature extractors
[trainDir, testDir] = getFeaturesDirectories();
featureExtractors = {...
%     PixelFeatures(); ...
%     HmaxFeatures(); ...
%     AlexnetPool5Features(); ...
    AlexnetWFc6Features(); ...
    AlexnetFc7Features(); ...
%     HopFeatures(10, BipolarFeatures(0.01, HmaxFeatures())); ...
%     HopFeatures(10, BipolarFeatures(0, AlexnetPool5Features())); ...
%     HopFeatures(10, BipolarFeatures(0, AlexnetFc7Features())); ...
%     RnnFeatures(4, [])...
%     NamedFeatures('RnnFeatures-timestep5')...
    };

%% Run
switch task
    case 'classification'
        featureProviderFactory = FeatureProviderFactory(...
            trainDir, testDir, dataset.pres, dataSelection);
        featureExtractors = cellfun(@(f) featureProviderFactory.get(f), ...
            featureExtractors, 'UniformOutput', false);
        classifier = @LibsvmClassifierCCV;
        runClassification(dataset, ...
            'dataPath', [fileparts(mfilename('fullpath')), '/data'], ...
            'dataSelection', dataSelection, ...
            'featureExtractors', featureExtractors, ...
            'classifier', classifier, ...
            varargin{:});
    case 'features'
        images = load('KLAB325.mat');
        images = images.img_mat;
        computeFeatures('data', dataset, 'dataSelection', dataSelection, ...
            'images', images, ...
            'featureExtractors', featureExtractors, ...
            'trainDirectory', trainDir, 'testDirectory', testDir, ...
            varargin{:});
    case 'features-hop'
        computeHopTimeFeatures(dataset, ...
            'trainDirectory', trainDir, 'testDirectory', testDir);
    otherwise
        error('Unknown task %s', task);
end
end

function [trainDir, testDir, directory] = getFeaturesDirectories()
%GETFEATURESDIRECTORY Get the directory the features are stored in.
directory = [fileparts(mfilename('fullpath')), '/data/features/'];
% use central cluster directory if possible
orchestraDir = '/groups/kreiman/martin/features/';
if exist(orchestraDir, 'dir')
    directory = orchestraDir;
end
trainDir = [directory, 'klab325_orig/'];
testDir = [directory, 'data_occlusion_klab325v2/'];
end
