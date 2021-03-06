function run(task, varargin)
addpath(genpath(pwd));
allowedTasks = {'classification', 'features', 'features-imagenet', ...
    'features-hop', 'features-hop-imagenet', 'features-hop-masked'};
assert(ismember(task, allowedTasks), ['task must be one of: ', ...
    sprintf('''%s'', ', allowedTasks{1:end - 1}), '''', ...
    allowedTasks{end}, '''']);

%% Args
argParser = inputParser();
argParser.KeepUnmatched = true;
argParser.addParameter('dataset', ...
    loadData('data/data_occlusion_klab325v2.mat', 'data'), ...
    @(d) ~isempty(d) && isa(d, 'dataset'));
argParser.addParameter('images', loadData('KLAB325.mat', 'img_mat'), ...
    @(i) ~isempty(i) && iscell(i));
argParser.addParameter('dataSelection', [], @isnumeric);
argParser.addParameter('excludeCategories', [], @isnumeric);
argParser.addParameter('featureExtractors', {});
argParser.addParameter('trainDirectory', [], @(p) exist(p, 'dir'));
argParser.addParameter('testDirectory', [], @(p) exist(p, 'dir'));
argParser.addParameter('bipolarizationValue', 0, @isnumeric);
argParser.addParameter('resultsFilename', ...
    datestr(datetime(), 'yyyy-mm-dd_HH-MM-SS'), @ischar);

argParser.parse(varargin{:});
fprintf('Running %s in %s with args:\n', task, pwd);
disp(argParser.Results);
dataset = argParser.Results.dataset;
images = argParser.Results.images;
dataSelection = argParser.Results.dataSelection;
if ismember('dataSelection', argParser.UsingDefaults)
    dataSelection = 1:size(dataset, 1);
end
excludedCategories = argParser.Results.excludeCategories;
featureExtractors = argParser.Results.featureExtractors;
trainDir = argParser.Results.trainDirectory;
testDir = argParser.Results.testDirectory;
bipolarizationValue = argParser.Results.bipolarizationValue;

%% Run
switch task
    case 'classification'
        adjustTestImages = createAdjustTestImages(dataset);
        featureProviderFactory = FeatureProviderFactory(...
            trainDir, testDir, dataset.pres, dataSelection, ...
            images, adjustTestImages);
        featureExtractors = cellfun(@(f) featureProviderFactory.get(f), ...
            featureExtractors, 'UniformOutput', false);
        varargin = replaceOrAddVararg(varargin, ...
            'featureExtractors', featureExtractors);
        classifier = @LibsvmClassifierCCV;
        dataSelection = dataSelection(...
            ~ismember(dataset.truth(dataSelection), excludedCategories));
        varargin = replaceOrAddVararg(varargin, ...
            'dataSelection', dataSelection);
        runTask(...
            'dataPath', [fileparts(mfilename('fullpath')), '/data'], ...
            'kfoldValues', unique(dataset.pres(dataSelection)), ...
            'getRows', curry(@getRows, dataset, dataSelection), ...
            'getLabels', @(rows) dataset.truth(rows), ...
            'classifier', classifier, ...
            'resultsFilename', [argParser.Results.resultsFilename, '.mat'], ...
            varargin{:});
    case 'features'
        adjustTestImages = createAdjustTestImages(dataset);
        computeFeatures('dataSelection', dataSelection, ...
            'images', images, 'objectForRow', dataset.pres, ...
            'adjustTestImages', adjustTestImages, ...
            'featureExtractors', featureExtractors, ...
            'trainDirectory', trainDir, 'testDirectory', testDir, ...
            varargin{:});
    case 'features-imagenet'
        objects = 1:size(dataset, 1);
        adjustTestImages = curry(@occludeImages, ...
            dataset.numBubbles, dataset.bubbleCenters, ...
            dataset.bubbleSigmas);
        computeFeatures('dataSelection', dataSelection, ...
            'images', images, 'objectForRow', objects, ...
            'adjustTestImages', adjustTestImages, ...
            'featureExtractors', featureExtractors, ...
            'trainDirectory', trainDir, 'testDirectory', testDir, ...
            varargin{:});
    case 'features-hop'
        savesteps = [1:100, 110:10:300];
        featureProviderFactory = FeatureProviderFactory(trainDir, testDir, ...
            dataset.pres, 1:length(dataset));
        featureExtractor = HopFeatures(max(savesteps), ...
            BipolarFeatures(bipolarizationValue, ...
            featureProviderFactory.get(featureExtractors)));
        weightsDirectory = [trainDir, '/../weights/'];
        if ~exist(weightsDirectory, 'dir')
            mkdir(weightsDirectory);
        end
        computeHopTimeFeatures(...
            'objectForRow', dataset.pres, ...
            'trainDirectory', trainDir, 'testDirectory', testDir, ...
            'weightsDirectory', weightsDirectory, ...
            'featureExtractor', featureExtractor, ...
            'savesteps', savesteps, ...
            varargin{:});
    case 'features-hop-imagenet'
        savesteps = [1:100, 110:10:300];
        objects = (1:50000)';
        featureProviderFactory = FeatureProviderFactory(trainDir, testDir, ...
            objects, objects);
        featureExtractor = HopFeatures(max(savesteps), ...
            BipolarFeatures(0, ...
            featureProviderFactory.get(featureExtractors)));
        weightsDirectory = [trainDir, '/../weights-imagenet/'];
        if ~exist(weightsDirectory, 'dir')
            mkdir(weightsDirectory);
        end
        computeHopTimeFeatures(...
            'objectForRow', objects, ...
            'trainDirectory', trainDir, 'testDirectory', testDir, ...
            'weightsDirectory', weightsDirectory, ...
            'featureExtractor', featureExtractor, ...
            'savesteps', savesteps, ...
            varargin{:});
    case 'features-hop-masked'
        runMaskedHopFeatures(...
            'objectForRow', dataset.pres, ...
            'trainDirectory', trainDir, 'testDirectory', testDir, ...
            varargin{:});
    otherwise
        error('Unknown task %s', task);
end
end


function rows = getRows(dataset, dataSelection, pres, runType)
if runType == RunType.Train
    selectedData = dataset(dataSelection, :);
    [~, rows] = unique(selectedData, 'pres');
    rows = dataSelection(rows);
else
    rows = dataSelection;
end
rows = rows(ismember(dataset.pres(rows), pres));
assert(all(sort(unique(dataset.pres(rows))) == sort(pres)));
if runType == RunType.Train
    assert(length(rows) == length(pres));
end
end

function adjustTestImages = createAdjustTestImages(dataset)
if ~ismember('bubbleSigmas', dataset.Properties.VarNames)
    bubbleSigmas = repmat(14, size(dataset, 1), max(dataset.nbubbles));
else
    bubbleSigmas = dataset.bubbleSigmas;
end
adjustTestImages = curry(@occludeImages, ...
    dataset.nbubbles, dataset.bubble_centers, bubbleSigmas);
end
