//
//  IFDiff.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 19/05/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFDiff.h"


@implementation IFDiff

// = Initialisation =

- (id) init {
	return [self initWithSourceArray: [NSArray array]
					destinationArray: [NSArray array]];
}

- (id) initWithSourceArray: (NSArray*) newSourceArray
		  destinationArray: (NSArray*) newDestArray {
	self = [super init];
	
	if (self) {
		sourceArray = [newSourceArray retain];
		destArray = [newDestArray retain];
	}
	
	return self;
}

- (void) dealloc {
	[sourceArray release];
	[destArray release];
	
	[super dealloc];
}

// = Performing the comparison =

struct diff_hash {
	int serial;
	unsigned hash;
};

struct diff_equivalence {
	int serial;
	BOOL last;
};

struct diff_candidate {
	int srcItem;
	int destItem;
	struct diff_candidate* previous;
};

static int hashCompare(const void* a, const void* b) {
	const struct diff_hash* aHash = a;
	const struct diff_hash* bHash = b;
	
	if (aHash->hash > bHash->hash) {
		return 1;
	} else if (aHash->hash < bHash->hash) {
		return -1;
	} else {
		if (aHash->serial > bHash->serial) {
			return 1;
		} else if (aHash->serial < bHash->serial) {
			return -1;
		} else {
			return 0;
		}
	}
}

static int hashCompare2(const void* a, const void* b) {
	const struct diff_hash* aHash = a;
	const struct diff_hash* bHash = b;
	
	if (aHash->hash > bHash->hash) {
		return 1;
	} else if (aHash->hash < bHash->hash) {
		return -1;
	} else {
		return 0;
	}
}

- (NSArray*) compareArrays {
	int i,j;
    int destArrayCount = [destArray count];
    int sourceArrayCount = [sourceArray count];
	
	// Array 'V' described in the diff algorithm
	struct diff_hash hashArray[destArrayCount+1];
	
	// Hash all the destination elements
	for (j=1; j<=destArrayCount; j++) {
		hashArray[j].serial = j;
		hashArray[j].hash = [[destArray objectAtIndex: j-1] hash];
	}
	
	// Sort the array
	qsort(hashArray+1, destArrayCount, sizeof(struct diff_hash), hashCompare);

	// Array 'E' described in the diff algorithm
	struct diff_equivalence equiv[destArrayCount+1];
	
	equiv[0].serial = 0;
	equiv[0].last   = YES;
	
	// Work out the equivalence classes
	for (j=1; j<destArrayCount; j++) {
		equiv[j].serial = hashArray[j].serial;
		equiv[j].last   = hashArray[j].hash != hashArray[j+1].hash;
	}
	
	equiv[j].serial = hashArray[j].serial;
	equiv[j].last   = YES;
	
	// Array 'P' described in the diff algorithm. This points to the beginning of the class of lines in the destination equivalent to lines in the source
	int srcEquiv[sourceArrayCount+1];
	
	for (i=1; i<=sourceArrayCount; i++) {
		struct diff_hash searchHash;
		
		searchHash.serial = i;
		searchHash.hash = [[sourceArray objectAtIndex: i-1] hash];
		
		// Search for an item with the same hash
		struct diff_hash* diffItem = bsearch(&searchHash, hashArray+1, destArrayCount, sizeof(struct diff_hash), hashCompare2);
		
		if (diffItem == NULL) {
			srcEquiv[i] = 0;
		} else {
			j = diffItem - hashArray;
			while (!equiv[j-1].last) j--;
			srcEquiv[i] = j;
		}
	}
	
	// Array 'K' described in the diff algorithm
	int candidateSize = sourceArrayCount<destArrayCount?sourceArrayCount:destArrayCount;
	struct diff_candidate candidates[candidateSize+2];
	
	candidates[0].srcItem = 0;
	candidates[0].destItem = 0;
	candidates[0].previous = NULL;
	
	candidates[1].srcItem = sourceArrayCount + 2;
	candidates[1].destItem = destArrayCount + 2;
	candidates[1].previous = NULL;
	
	int lastCandidate = 0;
	
	// Find the longest common subsequences
	for (i=1; i<=sourceArrayCount; i++) {
		if (srcEquiv[i] != 0) {
			int p = srcEquiv[i];
			
			// 'Merge step': algorithm A.3 from the diff paper
			int candidateNum = 0;
			struct diff_candidate candidate = candidates[0];
			
			while (1) {
				int serial = equiv[p].serial;
				
				// FIXME: candidates is ordered on destItem, so we could binary search here
				int s;
				for (s=candidateNum; s<=lastCandidate; s++) {
					if (candidates[s].destItem < serial && candidates[s+1].destItem > serial) break;
				}
				
				if (s <= lastCandidate) {
					// (Step 4)
					if (candidates[s+1].destItem > serial) {
						candidates[candidateNum] = candidate;
						candidateNum = s+1;

						candidate.srcItem = i;
						candidate.destItem = serial;
						candidate.previous = candidates + s;
					}
					
					// (Step 5)
					if (s == lastCandidate) {
						candidates[lastCandidate+2] = candidates[lastCandidate+1];
						lastCandidate++;
						break;
					}
				}
				
				if (equiv[p].last) break;
				p++;
			}
			
			candidates[candidateNum] = candidate;
		}
	}
	
	// Array of Longest Common Subsequences
	int subsequence[sourceArrayCount+1];
	
	for (i=0; i<=sourceArrayCount; i++) subsequence[i] = 0;
	
	struct diff_candidate* candidate = candidates + lastCandidate;
	// candidate = candidate->previous;
	while (candidate) {
		subsequence[candidate->srcItem] = candidate->destItem;
		candidate = candidate->previous;
	}
	
	// Weed out jackpots (points where the hashes of items match
	for (i=1; i<=sourceArrayCount; i++) {
		if (subsequence[i] != 0) {
			NSObject* a = [sourceArray objectAtIndex: i-1];
			NSObject* b = [destArray objectAtIndex: subsequence[i]-1];
			
			if (![a isEqualTo: b]) {
				subsequence[i] = 0;
			}
		}
	}
	
	// Finally: produce a result (mapping of source items to destination items, or -1 for 'no item')
	NSMutableArray* res = [NSMutableArray array];
	for (i=1; i<=sourceArrayCount; i++) {
		NSNumber* num = [[NSNumber alloc] initWithInt: subsequence[i]-1];
		[res addObject: num];
		[num release];
	}
	
	return res;
}

@end
